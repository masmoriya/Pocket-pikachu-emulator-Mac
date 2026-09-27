import assert from 'node:assert/strict';

export function validateDetailColors(frames,masks) {
  const at=(id,x,y)=>Object.entries(masks[id]).find(([,ps])=>ps.includes(y*36+x))?.[0];
  const expect=(id,x,y,color)=>assert.equal(at(id,x,y),color,`${id}: ${x},${y}`);
  for(const id of ['bath.shower1','bath.shower2']) {
    expect(id,17,16,'ink');
    expect(id,18,18,'cheek');
  }
  for(const id of ['sandcastle.sand1','sandcastle.sand2']) {
    expect(id,23,19,'ink');
    expect(id,24,21,'cheek');
    assert.equal(masks[id].cheek.length,1);
  }
  for(const id of ['reading.sand1','reading.sand2','reading.nextPage']) {
    expect(id,19,20,'ink');
    expect(id,20,22,'cheek');
    assert.equal(masks[id].cheek.length,1);
  }
  for(const id of ['watchTV.stand1','watchTV.stand2']) {
    expect(id,20,22,'ink');
    expect(id,24,23,'cheek');
  }
  expect('watchTV.jump',24,20,'cheek');
  expect('watchTV.jump',24,21,'ink');
  expect('bath.bathLook',22,15,'cheek');
  for(const frame of frames.values()) {
    const id=frame.id;
    if(id.startsWith('licking.')) {
      // No non-source red or pink may spread onto the connected hand.
      for(const c of ['pink','cheek']) for(const p of masks[id][c]??[]) {
        if(!frame.pixels.includes(p)) assert(p%36<12,`Sweet color on Pikachu: ${id}`);
      }
    }
    if(id.startsWith('study.')) {
      for(const x of [7,9,18,20]) for(const y of [26,27,28,29]) {
        if(frame.pixels.includes(y*36+x))expect(id,x,y,'ink');
      }
    }
    if(id.startsWith('computer.')) {
      expect(id,7,7,'white');
      expect(id,3,10,'white');
      expect(id,2,22,'white');
      expect(id,12,22,'white');
      expect(id,0,24,'brown');
      expect(id,23,18,'brown');
      expect(id,23,21,'brown');
    }
    if(id.startsWith('buildingBlocks.')) {
      for(let x=5;x<=11;x++)expect(id,x,23,undefined);
    }
    if(id.startsWith('brushTeeth.')) {
      assert.equal((masks[id].blue??[]).some(p=>p%36>=20&&p%36<=26&&Math.floor(p/36)<=23),false);
    }
  }
  expect('licking.icecream1',6,26,'brown');
  expect('licking.icecream2',6,26,'brown');
  expect('licking.icecream1',6,16,'pink');
  expect('buildingBlocks.try',7,18,undefined);
  expect('yoyo.yoyo3',15,21,undefined);
  expect('yoyo.yoyo3',14,26,undefined);
  expect('sleep.enteringBed',16,25,'white');
  expect('study.studyAskHistory',0,1,'blue');
  expect('study.studyAnswerHistory',15,8,'blue');
}
