#!/usr/bin/env node
'use strict';

// Runs the pure ArkTS model code without HarmonyOS APIs or generated files.
// Transpilation is not an ArkTS semantic check; still build the app with Hvigor.
// Override TYPESCRIPT_PATH when DevEco Studio is installed elsewhere.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const projectRoot = path.resolve(__dirname, '..');
const modelRoot = path.join(projectRoot, 'entry', 'src', 'main', 'ets', 'model');
const typescriptPath = process.env.TYPESCRIPT_PATH ||
  'D:/Program Files/DevEco Studio/tools/hvigor/hvigor/node_modules/typescript';
let ts;
try {
  ts = require(typescriptPath);
} catch (error) {
  console.error('Cannot load DevEco TypeScript. Set TYPESCRIPT_PATH to its typescript package directory.');
  console.error(error.message);
  process.exit(1);
}

const moduleCache = new Map();
function loadModel(filePath) {
  const absolutePath = path.resolve(filePath);
  if (!absolutePath.startsWith(modelRoot + path.sep)) {
    throw new Error('Model test loader only accepts files inside ' + modelRoot);
  }
  if (moduleCache.has(absolutePath)) return moduleCache.get(absolutePath).exports;
  if (!fs.existsSync(absolutePath)) throw new Error('Required model source is missing: ' + absolutePath);
  const source = fs.readFileSync(absolutePath, 'utf8');
  const compiled = ts.transpileModule(source, {
    fileName: absolutePath.replace(/\.ets$/, '.ts'),
    compilerOptions: {
      target: ts.ScriptTarget.ES2020,
      module: ts.ModuleKind.CommonJS,
      strict: true,
      esModuleInterop: true
    },
    reportDiagnostics: true
  });
  const errors = (compiled.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error);
  if (errors.length) {
    throw new Error(errors.map(d => ts.flattenDiagnosticMessageText(d.messageText, '\n')).join('\n'));
  }
  const module = { exports: {} };
  moduleCache.set(absolutePath, module);
  const localRequire = specifier => {
    if (!specifier.startsWith('./') && !specifier.startsWith('../')) {
      throw new Error('Platform or external import is not supported by pure model tests: ' + specifier);
    }
    const base = path.resolve(path.dirname(absolutePath), specifier);
    const candidates = /\.(ets|ts)$/.test(base) ? [base] : [base + '.ets', base + '.ts'];
    const resolved = candidates.find(candidate => fs.existsSync(candidate));
    if (!resolved) throw new Error('Cannot resolve model import: ' + specifier);
    return loadModel(resolved);
  };
  const wrapper = new vm.Script('(function(require, module, exports) {\n' + compiled.outputText + '\n})', {
    filename: absolutePath
  });
  wrapper.runInNewContext({ console, Date, Math, JSON, Set, Map })(localRequire, module, module.exports);
  return module.exports;
}

const tests = [];
function test(name, action) { tests.push({ name, action }); }
function plain(value) { return JSON.parse(JSON.stringify(value)); }


const engine = loadModel(path.join(modelRoot, 'ModelEngine.ets')).ModelEngine;
const decision = loadModel(path.join(modelRoot, 'DecisionEngine.ets')).DecisionEngine;
function fixture() {
 return {id:'m',name:'测试',description:'',createdAt:1,root:{id:'root',name:'动物',description:'',attributes:[],collapsed:false,children:[
 {id:'mammal',name:'哺乳',description:'',attributes:['温血','胎生'],collapsed:false,children:[
 {id:'cat',name:'猫',description:'',attributes:['宠物'],collapsed:false,children:[]},
 {id:'lion',name:'狮',description:'',attributes:['野生'],collapsed:false,children:[]}]},
 {id:'bird',name:'鸟',description:'',attributes:['温血','羽毛'],collapsed:false,children:[]}]}};
}
test('six upstream samples import without data loss',()=>{
 const samples=engine.samples();assert.equal(samples.length,6);
 assert.equal(engine.parseModels(JSON.stringify(samples)).length,6);
 samples[0].root.name='changed';assert.notEqual(engine.samples()[0].root.name,'changed');
});
test('add child and sibling are immutable and expose new selection',()=>{
 const m=fixture();const old=JSON.stringify(m);const child=engine.add(m,'cat',false);
 assert.equal(JSON.stringify(m),old);assert.equal(engine.find(child.root,'cat').children.length,1);
 assert.equal(engine.find(child.root,engine.lastAddedId).name,'新概念');
 const sib=engine.add(m,'cat',true);assert.equal(engine.find(sib.root,'mammal').children.length,3);
 assert.equal(engine.find(sib.root,'mammal').children[1].id,engine.lastAddedId);
 assert.equal(engine.add(m,'root',true).root.children.length,2);assert.equal(engine.lastAddedId,'');
});
test('delete removes complete subtree and protects root',()=>{
 const m=fixture();const out=engine.remove(m,'mammal');assert.equal(engine.find(out.root,'cat'),undefined);
 assert.equal(engine.find(out.root,'lion'),undefined);assert.equal(m.root.children.length,2);
 assert.equal(engine.all(engine.remove(m,'root').root).length,5);
});
test('update trims and deduplicates attributes without mutating source',()=>{
 const m=fixture();const out=engine.update(m,'cat',' 家猫 ',' 描述 ',[' 宠物 ','宠物','',' 小型 ']);
 assert.equal(engine.find(out.root,'cat').name,'家猫');assert.deepEqual(plain(engine.find(out.root,'cat').attributes),['宠物','小型']);
 assert.equal(engine.find(m.root,'cat').name,'猫');
});
test('collapse hides descendants in graph and outline while search finds them',()=>{
 const m=fixture();const out=engine.collapse(m,'mammal');const layout=engine.layout(out.root);
 assert.equal(layout.nodes.length,3);assert.equal(engine.flatten(out.root).length,3);
 assert.equal(engine.flatten(out.root,'猫').length,1);assert.equal(engine.all(out.root).length,5);
 const expanded=engine.expandAll(out,false);assert.equal(engine.layout(expanded.root).nodes.length,5);
 assert.ok(engine.layout(m.root).height>layout.height);
});
test('all walks collapsed trees without mutating nodes or flags',()=>{
 const m=fixture();m.root.children[0].collapsed=true;const before=JSON.stringify(m);
 const rows=engine.all(m.root);assert.equal(rows.length,5);assert.equal(rows[1].node.collapsed,true);
 assert.equal(JSON.stringify(m),before);assert.equal(rows[2].depth,2);assert.equal(rows[2].path,'动物 / 哺乳 / 猫');
});
test('rename and duplicate create independent models',()=>{
 const m=fixture();const renamed=engine.rename(m,' 新模型 ',' 说明 ');
 assert.equal(renamed.name,'新模型');assert.equal(renamed.description,'说明');assert.equal(m.name,'测试');
 const duplicate=engine.duplicate(m);assert.match(duplicate.name,/副本$/);assert.notEqual(duplicate.id,m.id);
 const originalIds=engine.all(m.root).map(r=>r.node.id);const copiedIds=engine.all(duplicate.root).map(r=>r.node.id);
 assert.equal(copiedIds.length,originalIds.length);assert.equal(new Set(copiedIds).size,copiedIds.length);
 assert.equal(originalIds.some(id=>copiedIds.includes(id)),false);
 duplicate.root.name='changed';assert.equal(m.root.name,'动物');
});
test('layout cards do not overlap and have parent-before-child coordinates',()=>{
 const layout=engine.layout(fixture().root);assert.equal(layout.nodes.length,5);
 for(let i=0;i<layout.nodes.length;i++)for(let j=i+1;j<layout.nodes.length;j++){
 const a=layout.nodes[i],b=layout.nodes[j];assert.ok(Math.abs(a.x-b.x)>=156||Math.abs(a.y-b.y)>=60);
 }
 assert.ok(layout.width>0&&layout.height>0);
});
test('rules inherit conditions, ignore collapse and omit conditionless leaves',()=>{
 const m=fixture();m.root.children[0].collapsed=true;const rules=engine.rules(m.root);
 const cat=rules.find(r=>r.nodeId==='cat');assert.deepEqual(plain(cat.conditions),['温血','胎生','宠物']);
 assert.equal(cat.path,'动物 / 哺乳 / 猫');assert.equal(rules.length,3);
 assert.equal(engine.rules(engine.blank('空白').root).length,0);
});
test('strict import rejects malformed arrays, duplicate IDs and bad attributes',()=>{
 assert.throws(()=>engine.parseModels('{}'));assert.equal(engine.parseModels('[]').length,0);
 let m=fixture();m.root.children[0].id='root';assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 m=fixture();m.root.attributes=[7];assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 m=fixture();m.root.children=null;assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 m=fixture();assert.throws(()=>engine.parseModels(JSON.stringify([m,m])));
});
test('import enforces node and depth budgets',()=>{
 let m=fixture();m.root.children=[];for(let i=0;i<3001;i++)m.root.children.push({id:'c'+i,name:'概念',description:'',attributes:[],collapsed:false,children:[]});
 assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 m=fixture();let n=m.root;for(let i=0;i<35;i++){let c={id:'d'+i,name:'概念',description:'',attributes:[],collapsed:false,children:[]};n.children=[c];n=c;}
 assert.throws(()=>engine.parseModels(JSON.stringify([m])));
});
test('import enforces UTF-8 bytes and text limits',()=>{
 let m=fixture();m.description='好'.repeat(10001);assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 m=fixture();m.root.id='x'.repeat(201);assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 m=fixture();m.root.description='a'.repeat(10001);assert.throws(()=>engine.parseModels(JSON.stringify([m])));
 // 4 MB is measured in UTF-8 bytes: multibyte text must not slip through by JS length.
 m=fixture();m.description='好'.repeat(3*1024*1024);assert.throws(()=>engine.parseModels(JSON.stringify([m])));
});

test('decision engine evaluates, ranks, and picks informative questions',()=>{
 const m=fixture();
 let result=decision.evaluate(m,[{attribute:'温血',value:'yes'},{attribute:'宠物',value:'yes'}]);
 assert.equal(result[0].status,'pending');assert.equal(result[0].rule.nodeId,'cat');assert.deepEqual(plain(result[0].missing),['胎生']);
 result=decision.evaluate(m,[{attribute:'温血',value:'yes'},{attribute:'胎生',value:'yes'},{attribute:'宠物',value:'yes'}]);
 assert.equal(result[0].status,'matched');assert.equal(result[0].rule.nodeId,'cat');
 const q=decision.nextQuestion(m,[]);assert.equal(q.attribute,'胎生');assert.equal(q.yesCount,2);assert.equal(q.noCount,1);
 assert.equal(decision.nextQuestion(m,[{attribute:'温血',value:'unknown'}]).attribute,'胎生');
});
test('decision conversion includes every node and isolated copies',()=>{
 const m=fixture();const bundle=decision.convert(m);
 assert.equal(bundle.format,'intermodeller.conversion');assert.equal(bundle.version,1);assert.equal(bundle.rows.length,5);
 const cat=bundle.rows.find(r=>r.nodeId==='cat');assert.deepEqual(plain(cat.inheritedAttributes),['温血','胎生','宠物']);
 assert.equal(cat.leaf,true);assert.ok(bundle.attributes.includes('羽毛'));assert.equal(bundle.rules.length,3);
 bundle.source.root.name='altered';bundle.rows[0].ownAttributes.push('x');assert.equal(m.root.name,'动物');assert.equal(m.root.attributes.includes('x'),false);
});

async function run() {
  let passed = 0;
  for (const item of tests) {
    try {
      await item.action();
      passed += 1;
      console.log('PASS ' + item.name);
    } catch (error) {
      console.error('FAIL ' + item.name);
      console.error(error.stack || String(error));
    }
  }
  console.log('\n' + passed + '/' + tests.length + ' tests passed (TypeScript ' + ts.version + ').');
  if (passed !== tests.length || tests.length === 0) process.exitCode = 1;
}

run().catch(error => {
  console.error(error.stack || String(error));
  process.exitCode = 1;
});
