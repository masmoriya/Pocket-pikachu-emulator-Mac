// Execute the original choreography against a virtual clock. No browser or network.
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readFileSync(path.join(root, 'script.js'), 'utf8');
const anims = JSON.parse(fs.readFileSync(path.join(root, 'anims.json'), 'utf8'));
const frames = [];
const identifiers = new Map();
const interfaces = new Set(['status','settings','settingsRel','settingsDiff','gift','game','watts','givenWatts','clock','totalSteps','settingsBackup','finalScreen','record']);
function flatten(value, id) {
  if (Array.isArray(value) && value.every(v => typeof v === 'string')) {
    identifiers.set(value, id);
    const pixels = value.map(v => Number(v.replace('num-', '')));
    // Original renderer only displays indices 0..<1080. Keep raw data separately.
    frames.push({id, category: interfaces.has(id.split('.')[0]) ? 'interface' : 'character', pixels: [...new Set(pixels.filter(p => p >= 0 && p < 1080))], sourcePixels: pixels});
  } else for (const [key, child] of Object.entries(value)) flatten(child, id ? `${id}.${key}` : key);
}
flatten(anims, '');
frames.push({id: 'blank', category: 'utility', pixels: [], sourcePixels: []});
const functions = source.slice(source.indexOf('    function standLike('), source.indexOf('    function restartTamagotchi'));
const globals = source.slice(source.indexOf('// Anim vars'), source.indexOf("document.addEventListener('DOMContentLoaded'"));
function capture(id, label, call, setup = '', finite = false, random = 0.8) {
  let now = 0, nextID = 1, stopped = false;
  const timers = new Map(), changes = [];
  class Clock extends Date { constructor(...args) { super(...(args.length ? args : [new Date(2026, 0, 1, 12).getTime() + now])); } }
  const node = {classList: {add() {}, remove() {}}, innerHTML: ''};
  const schedule = (fn, ms, repeat) => { const key = nextID++; timers.set(key, {fn, ms, due: now + ms, repeat}); return key; };
  const context = vm.createContext({Anims: anims, DisplayScreen: node, Date: Clock,
    Math: Object.assign(Object.create(Math), {random: () => random}), console: {log() {}},
    localStorage: {getItem: k => k.startsWith('hasReach') ? '1' : null, setItem() {}},
    document: {cookie: '', querySelector: () => node},
    setInterval: (fn, ms) => schedule(fn, ms, true), setTimeout: (fn, ms) => schedule(fn, ms, false),
    clearInterval: id => timers.delete(id), clearTimeout: id => timers.delete(id),
    basicAnim: () => { stopped = true; }, updateFriendshipLevel() {},
    clearAllTimeouts: () => timers.clear(),
    loadAnim: (_, frame) => {
      const name = frame == null ? 'blank' : identifiers.get(frame);
      if (!name) throw Error(`${id}: unidentified source frame`);
      if (changes.at(-1)?.at === now) changes.pop();
      if (changes.at(-1)?.frame !== name) changes.push({frame: name, at: now});
    }
  });
  vm.runInContext(globals + '\n' + functions + '\nrandomAnim = 8; randomAnimEat = 12;\n' + setup + '\n' + call, context);
  for (let count = 0; count < 10000 && !stopped && timers.size; count++) {
    const [key, timer] = [...timers].sort((a,b) => a[1].due-b[1].due)[0];
    if (timer.due > 360000) break;
    now = timer.due;
    if (timer.repeat) timer.due += timer.ms; else timers.delete(key);
    timer.fn();
  }
  if (!changes.length) throw Error(`No frames for ${id}`);
  let steps = changes.map((c,i) => ({frame: c.frame, duration: ((changes[i+1]?.at ?? (stopped ? now : now + 500)) - c.at) / 1000})).filter(step => step.duration > 0);
  let loopStart = 0;
  if (!finite) {
    outer: for (let start = 0; start < Math.min(steps.length, 80); start++) {
      for (let size = 1; size <= (steps.length-start-1)/3; size++) {
        const a = JSON.stringify(steps.slice(start,start+size));
        if (a === JSON.stringify(steps.slice(start+size,start+size*2)) && a === JSON.stringify(steps.slice(start+size*2,start+size*3))) {
          steps = steps.slice(0,start+size); loopStart = start; break outer;
        }
      }
    }
  }
  return {id, label, source: call, loop: !finite, loopStart, steps, props: []};
}
const specs = [
 ['love','Affectionate','standLove()'], ['loveHello','Hello','standLove(true)', '', true],
 ['like','Content','standLike()'], ['likeHello','Content greeting','standLike(true)'], ['return','Coming back','backFromLeft()', '', true],
 ['start','Hatching','pokeinit()'], ['tongue','Tongue','tongueAnim()', '', true],
 ['yawn','Delighted','yawnAnim()', '', true], ['happy','Happy steps','happySteps()', '', true],
 ['hearts','Hearts','heartSmiles()', '', true], ['letter','Writing a letter','writtingLetter()', '', true],
 ['flying','Flying','flying()', '', true], ['diving','Diving','diving()', '', true],
 ['ball','Rolling a ball','rollingBall()', '', true], ['horn','Playing horn','playingHorn()', '', true],
 ['flip','Backflip','backFlip()', '', true], ['piano','Playing piano','playPiano()', '', true],
 ['toast','Eating toast','eating()', 'randomAnimEat = 1;'],
 ['onigiri','Eating onigiri','eating()', 'randomAnimEat = 8;'], ['rice','Eating rice','eating()'],
 ['tableToast','Upset at toast','eating(true)', "throwTableAnim = 'Toast';", true],
 ['tableOnigiri','Upset at onigiri','eating(true)', "throwTableAnim = 'Onigiri';", true],
 ['tableRice','Upset at rice','eating(true)', "throwTableAnim = '';", true],
 ['walk','Walking','walking()'], ['shower','Showering','bathTime()', 'randomAnim = 1;'],
 ['bath','Bathing','bathTime()'], ['sand','Sandcastle','sandcastle()'], ['sandFast','Building sandcastle','sandcastle(true)'],
 ['reading','Reading','reading()'], ['page','Turning a page','reading(true)', '', true],
 ['tv','Watching TV','watchTV()'], ['tvExcited','Excited at TV','watchTV(true)'],
 ['lolly','Lollipop','licking()', 'randomAnim = 1;'], ['icecream','Ice cream','licking()'],
 ['dropLolly','Dropped lollipop','licking()', 'randomAnim = 1; throwCandy = true;', true],
 ['dropIcecream','Dropped ice cream','licking()', 'throwCandy = true;', true],
 ...['history','maths','english'].map(s => [s, `Studying ${s}`, `study('${s}')`, 'isAskingStudy = true; itHasBeenAwakedFromStudy = true;']),
 ['studySleep','Sleeping while studying', "study('history')", '', false, 0.1],
 ['kite','Flying a kite','flyKite()'], ['kiteFast','Fast kite','flyKite(true)'],
 ['rc','Remote control car','playingRC()'], ['rcFast','Fast remote control car','playingRC(true)', 'isFastRC = true;'],
 ['computer','Using computer','computer()'], ['typing','Typing','computer(true)'],
 ['yoyo','Playing yo-yo','playingYoyo()'], ['yoyoDog','Yo-yo trick','playingYoyo()', 'isDogTrick = true;'],
 ['blocks','Building blocks','buildingBlocks()'], ['blocksFall','Falling blocks','buildingBlocks()', 'throwBlocks = true;', true],
 ['brush','Brushing teeth','brushTeeth()'], ['brushFast','Brushing quickly','brushTeeth(true)']
];
const clips = specs.map(s => capture(...s));
function manual(id, label, steps, loop=true) { clips.push({id,label,source:'script.js basicAnim / interaction branches',loop,loopStart:0,steps: steps.map(([frame,duration]) => ({frame,duration})),props:[]}); }
for (const side of ['front','side','back']) manual(`sleep-${side}`, `Sleeping (${side})`, [[`sleep.${side}Sleep`,1.2],[`sleep.${side}Sleep2`,1.2]]);
manual('wakeStudy','Waking from study',[['study.studyAwake',0.5]],false);
manual('look','Looking at you',[['standBasic.look',2.5]],false);
manual('madLook','Upset glance',[['standMad.look',3]],false);
manual('showerLook','Shower glance',[['bath.showerLook',2]],false);
manual('bathLook','Bath glance',[['bath.bathLook',2]],false);
manual('pop','Poké Ball opening',[['start.pop1',0.8],['start.pop2',2]],false);
manual('bed','Going to bed',[['sleep.goingToSleep',2],['sleep.enteringBed',1]],false);
manual('neutral','Neutral',[['standBasic.stand',3],['standBasic.extend',1]]);
manual('mad','Upset',[['standMad.stand',1]]);
manual('left','Away',[['standLeft',0.5],['blank',0.5]]);
// A greeting hands control back to the idle function; capture only the greeting itself.
const hello = clips.find(c => c.id === 'loveHello');
hello.steps = ['helloLeft','helloRight','helloLeft','helloRight'].map(key => ({frame:`standLove.${key}`,duration:0.5}));
clips.find(c => c.id === 'page').steps[0].duration = 1.1;
for (const clip of clips) {
  if (clip.loop && clip.steps.at(-1).duration > 30) {
    clip.steps.at(-1).duration = 2;
    clip.loopStart = clip.steps.length - 1;
  }
  clip.completion = clip.loop ? 'loop' : 'returnToPreviousActivity';
  const propGroups = {eating:'table and food',bath:'bath or shower',sleep:'bed',study:'desk and book',reading:'book',computer:'computer and desk',piano:'piano',yoyo:'yo-yo',flyingKite:'kite',radioControl:'remote control car',buildingBlocks:'blocks',sandcastle:'sandcastle',letter:'desk and letter',horn:'horn',rollingBall:'ball',watchTV:'television',brushTeeth:'sink and toothbrush',licking:'snack'};
  clip.props = [...new Set(clip.steps.map(s=>propGroups[s.frame.split('.')[0]]).filter(Boolean))];
}
// Include every frame as an inspectable pose, including otherwise unreachable source variants.
const valid = new Set(frames.map(f => f.id));
for (const clip of clips) for (const step of clip.steps) if (!valid.has(step.frame) || step.duration <= 0) throw Error(`Invalid ${clip.id}: ${JSON.stringify(step)}`);
const manifest = {version:1,width:36,height:30,sourceFrameCount:frames.length-1,frames,clips};
const out = path.join(root,'mac/Sources/PocketPikachu/Resources/animations.json');
fs.writeFileSync(out,JSON.stringify(manifest));
console.log(`Extracted ${frames.length-1} source frames and ${clips.length} clips.`);
