import assert from 'node:assert/strict';
export function validateFinalColors(frames,masks) {
  const at=(id,x,y)=>Object.entries(masks[id]).find(([,ps])=>ps.includes(y*36+x))?.[0];
  const expect=(id,x,y,c)=>assert.equal(at(id,x,y),c,`${id}: ${x},${y}`);
  for(const f of frames.values()) {
    const id=f.id;
    if(id.startsWith('study.')||id.startsWith('letter.write')) {
      for(const p of f.pixels)if(p%36>=6&&p%36<=20&&Math.floor(p/36)>=24)expect(id,p%36,Math.floor(p/36),'ink');
      expect(id,8,27,'brown');
      expect(id,19,27,'brown');
    }
    if(id.startsWith('computer.')) {
      for(const p of f.pixels)if(p%36<=16&&Math.floor(p/36)>=23)expect(id,p%36,Math.floor(p/36),'ink');
      expect(id,0,24,'brown');
      expect(id,12,28,'brown');
    }
    if(id.startsWith('buildingBlocks.')) {
      expect(id,id==='buildingBlocks.try'?21:22,15,'cheek');
      assert.equal(masks[id].cheek.length,1);
    }
    if(id.startsWith('radioControl.'))for(const points of Object.values(masks[id]))for(const p of points) {
      if(Math.floor(p/36)===29)assert(f.pixels.includes(p),`Filled space beneath car: ${id}`);
    }
    if(id.startsWith('walk.'))for(const points of Object.values(masks[id]))for(const p of points) {
      if(Math.floor(p/36)<14)assert(f.pixels.includes(p),`Filled text counter: ${id}`);
    }
    if(id.startsWith('piano.')) {
      assert(!masks[id].cheek,`Hidden cheek visible: ${id}`);
      expect(id,id.endsWith('right')?8:26,18,'fur');
    }
    if(id.includes('Chopsticks')) {
      const dy=id.endsWith('2')?1:0;
      expect(id,17,15+dy,'white');
      expect(id,14,19+dy,'white');
      expect(id,4,26,'brown');
    }
  }
  for(const id of ['heartSmiles.loveLeft','heartSmiles.loveRight']) {
    assert(masks[id].cheek.length>=15);
    const patches=id.endsWith('loveLeft')?[[19,13],[11,16]]:[[14,13],[22,16]];
    const cheeks=new Set();
    for(const [left,top]of patches)for(let y=top;y<top+2;y++)for(let x=left;x<left+2;x++){
      cheeks.add(y*36+x);expect(id,x,y,'cheek');
    }
    assert.equal(masks[id].cheek.filter(p=>p>=9*36).length,8,`Two whole cheek squares: ${id}`);
    for(const p of frames.get(id).pixels)if(p>=9*36&&!cheeks.has(p))expect(id,p%36,Math.floor(p/36),'ink');
  }
  expect('bath.bath2',16,15,'ink');
  expect('bath.bath2',19,16,'cheek');
  expect('brushTeeth.brush1',17,15,'white');
  expect('brushTeeth.brush1',12,18,'white');
  expect('brushTeeth.brush2',16,15,'white');
  expect('brushTeeth.brush2',13,17,'white');
  expect('licking.icecreamFall',5,27,'pink');
  expect('licking.icecreamFall',9,28,'brown');
  expect('licking.lollypopFall',4,29,'cheek');
  expect('horn.hornLeft10',35,12,undefined);
  expect('horn.hornRight10',0,12,undefined);
  expect('standLove.helloLeft',8,15,undefined);
  expect('standLove.helloRight',27,15,undefined);
  for(const x of [18,19])for(const y of [14,15])expect('standLike.lookRight',x,y,'cheek');
  for(const [id,x,y]of [['eating.eatingToast',15,14],['eating.nomnomToast',21,15],['eating.nomnomToast2',21,16]]) {
    expect(id,x,y,'white');
    expect(id,13,23,'white');
    // The white toast cannot spread into the connected face/hand region.
    expect(id,13,15,'fur');
  }
}
