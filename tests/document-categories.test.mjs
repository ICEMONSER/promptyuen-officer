import test from 'node:test';
import assert from 'node:assert/strict';
import {documentCategory} from '../lib/document-categories.js';
test('sample and received documents use the same category',()=>{
 for(const kind of ['identity','license','vehicle']){
  assert.equal(documentCategory({kind}),kind);
  assert.equal(documentCategory({id:`case/token/${kind}/file.png`}),kind);
 }
 assert.equal(documentCategory({name:'ใบขับขี่.png'}),'license');
 assert.equal(documentCategory({id:'old-file',name:'unknown.png'}),'other');
});
