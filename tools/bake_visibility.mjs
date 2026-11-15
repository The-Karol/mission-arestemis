// Bake conservative line-of-sight masks through the opaque room partitions.
// The projection encloses ALL segments between a camera cell and a target box.
import { readFileSync, writeFileSync } from "node:fs";
const {targets, walls} = JSON.parse(readFileSync("build/visibility_geometry.json","utf8"));
const boxes = targets.map(key => key.split(",").map(v => Number(v)*2));
const partitions = walls.map(box => {
  const sizes = [0,1,2].map(i => box[i+3]-box[i]);
  const a = sizes.indexOf(Math.min(...sizes));
  return {box,a,b:(a+1)%3,c:(a+2)%3,plane:(box[a]+box[a+3])/2};
}).filter(w => w.box[w.a+3]-w.box[w.a]<0.55);

function covered(eye, target, w) {
  const a=w.a, p=w.plane;
  let near, far;
  if (eye[a+3]<p && p<target[a]) {
    near=(p-eye[a+3])/(target[a+3]-eye[a+3]);
    far=(p-eye[a])/(target[a]-eye[a]);
  } else if (target[a+3]<p && p<eye[a]) {
    near=(eye[a]-p)/(eye[a]-target[a]);
    far=(eye[a+3]-p)/(eye[a+3]-target[a+3]);
  } else return false;
  for (const i of [w.b,w.c]) {
    const low=eye[i],high=eye[i+3];
    const d=target[i]-low, h=target[i+3]-high;
    if (low+Math.min(near*d,far*d)<w.box[i]+0.01 ||
        high+Math.max(near*h,far*h)>w.box[i+3]-0.01) return false;
  }
  return true;
}
const cells={};
for(let x=-13;x<=25;x++) for(let y=-1;y<=5;y++) for(let z=-8;z<=8;z++){
  const eye=[x*3-.22,y*2-.22,z*3-.22,(x+1)*3+.22,(y+1)*2+.22,(z+1)*3+.22];
  const mask=Buffer.alloc(Math.ceil(targets.length/8));
  for(let i=0;i<boxes.length;i++){
    if(partitions.some(w=>covered(eye,boxes[i],w))) mask[i>>3]|=1<<(i%8);
  }
  cells[[x,y,z].join(",")]=mask.toString("base64");
}
writeFileSync("data/facility_visibility.json",JSON.stringify({keys_ordered:targets,cells}));
console.log(targets.length,"render groups;",Object.keys(cells).length,"observer cells.");
