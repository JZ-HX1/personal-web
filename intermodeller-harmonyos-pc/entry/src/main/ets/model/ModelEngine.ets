import { SAMPLE_MODELS } from './Samples';

export interface ConceptNode {
  id: string;
  name: string;
  description: string;
  attributes: string[];
  collapsed: boolean;
  children: ConceptNode[];
}
export interface ConceptModel {
  id: string;
  name: string;
  description: string;
  createdAt: number;
  root: ConceptNode;
}
export interface FlatNode { node: ConceptNode; depth: number; path: string; }
export interface PositionedNode { node: ConceptNode; x: number; y: number; depth: number; }
export interface TreeLayout { nodes: PositionedNode[]; width: number; height: number; }
export interface ConceptRule { concept: string; nodeId: string; conditions: string[]; path: string; }
interface BranchSize { width: number; height: number; }

export class ModelEngine {
  static lastAddedId: string = '';
  private static counter: number = 0;
  private static id(): string { return 'n-' + Date.now().toString(36) + '-' + (++ModelEngine.counter); }
  static samples(): ConceptModel[] { return JSON.parse(JSON.stringify(SAMPLE_MODELS)) as ConceptModel[]; }
  static clone(model: ConceptModel): ConceptModel { return JSON.parse(JSON.stringify(model)) as ConceptModel; }
  static rename(model: ConceptModel, name: string, description: string): ConceptModel {
    if (!name.trim() || name.trim().length > 200 || description.trim().length > 10000) {
      throw new Error('模型名称须为 1–200 字，说明最多 10000 字');
    }
    const copy = ModelEngine.clone(model);
    copy.name = name.trim();
    copy.description = description.trim();
    return copy;
  }
  static duplicate(model: ConceptModel): ConceptModel {
    const copy = ModelEngine.clone(model);
    copy.id = 'm-' + ModelEngine.id();
    copy.name = model.name + ' 副本';
    copy.createdAt = Date.now();
    ModelEngine.renewIds(copy.root);
    return copy;
  }
  private static renewIds(node: ConceptNode): void {
    node.id = ModelEngine.id();
    for (const child of node.children) ModelEngine.renewIds(child);
  }
  static blank(name: string): ConceptModel {
    return { id: 'm-' + ModelEngine.id(), name: name, description: '', createdAt: Date.now(),
      root: { id: ModelEngine.id(), name: name, description: '', attributes: [], collapsed: false, children: [] } };
  }
  static find(root: ConceptNode, id: string): ConceptNode | undefined {
    if (root.id === id) return root;
    for (const child of root.children) { const found = ModelEngine.find(child, id); if (found) return found; }
    return undefined;
  }
  static parent(root: ConceptNode, id: string): ConceptNode | undefined {
    for (const child of root.children) {
      if (child.id === id) return root;
      const found = ModelEngine.parent(child, id); if (found) return found;
    }
    return undefined;
  }
  static flatten(root: ConceptNode, query: string = ''): FlatNode[] {
    const rows: FlatNode[] = [];
    ModelEngine.collect(root, 0, '', rows, query.trim().toLowerCase());
    return rows;
  }
  private static collect(node: ConceptNode, depth: number, path: string, rows: FlatNode[], query: string): void {
    const full: string = path ? path + ' / ' + node.name : node.name;
    if (!query || node.name.toLowerCase().includes(query) || node.attributes.join(' ').toLowerCase().includes(query)) {
      rows.push({ node: node, depth: depth, path: full });
    }
    if (!node.collapsed || query.length > 0) {
      for (const child of node.children) ModelEngine.collect(child, depth + 1, full, rows, query);
    }
  }
  static all(root: ConceptNode): FlatNode[] {
    const rows: FlatNode[] = [];
    ModelEngine.collectAll(root, 0, '', rows);
    return rows;
  }
  private static collectAll(node: ConceptNode, depth: number, path: string, rows: FlatNode[]): void {
    const full: string = path ? path + ' / ' + node.name : node.name;
    rows.push({ node: node, depth: depth, path: full });
    for (const child of node.children) ModelEngine.collectAll(child, depth + 1, full, rows);
  }
  private static size(node: ConceptNode): BranchSize {
    if (node.collapsed || node.children.length === 0) return { width: 156, height: 60 };
    let width: number = 0;
    let height: number = 0;
    for (const child of node.children) { const size = ModelEngine.size(child); width = Math.max(width, size.width); height += size.height; }
    return { width: 224 + width, height: height + (node.children.length - 1) * 28 };
  }
  static layout(root: ConceptNode): TreeLayout {
    const size: BranchSize = ModelEngine.size(root);
    const nodes: PositionedNode[] = [];
    ModelEngine.place(root, 48, 48, 0, nodes);
    return { nodes: nodes, width: size.width + 96, height: size.height + 96 };
  }
  private static place(node: ConceptNode, x: number, y: number, depth: number, nodes: PositionedNode[]): void {
    const size: BranchSize = ModelEngine.size(node);
    nodes.push({ node: node, x: x, y: y + (size.height - 60) / 2, depth: depth });
    if (!node.collapsed) {
      let childY: number = y;
      for (const child of node.children) {
        ModelEngine.place(child, x + 224, childY, depth + 1, nodes);
        childY += ModelEngine.size(child).height + 28;
      }
    }
  }
  static add(model: ConceptModel, parentId: string, sibling: boolean): ConceptModel {
    ModelEngine.lastAddedId = '';
    const copy = ModelEngine.clone(model);
    const parent = sibling ? ModelEngine.parent(copy.root, parentId) : ModelEngine.find(copy.root, parentId);
    if (!parent) return copy;
    const id: string = ModelEngine.id();
    const child: ConceptNode = { id: id, name: '新概念', description: '', attributes: [], collapsed: false, children: [] };
    if (sibling) parent.children.splice(parent.children.findIndex((node: ConceptNode) => node.id === parentId) + 1, 0, child);
    else parent.children.push(child);
    parent.collapsed = false;
    ModelEngine.lastAddedId = id;
    return copy;
  }
  static remove(model: ConceptModel, id: string): ConceptModel {
    const copy = ModelEngine.clone(model);
    const parent = ModelEngine.parent(copy.root, id);
    if (parent) parent.children = parent.children.filter((node: ConceptNode) => node.id !== id);
    return copy;
  }
  static update(model: ConceptModel, id: string, name: string, description: string, attributes: string[]): ConceptModel {
    const copy = ModelEngine.clone(model);
    const node = ModelEngine.find(copy.root, id);
    if (node && name.trim()) {
      node.name = name.trim(); node.description = description.trim();
      node.attributes = attributes.map((item: string) => item.trim()).filter((item: string, index: number, all: string[]) => item.length > 0 && all.indexOf(item) === index);
    }
    return copy;
  }
  static collapse(model: ConceptModel, id: string): ConceptModel {
    const copy = ModelEngine.clone(model);
    const node = ModelEngine.find(copy.root, id); if (node) node.collapsed = !node.collapsed;
    return copy;
  }
  private static setCollapsed(node: ConceptNode, value: boolean): void {
    node.collapsed = value;
    for (const child of node.children) ModelEngine.setCollapsed(child, value);
  }
  static expandAll(model: ConceptModel, collapsed: boolean): ConceptModel {
    const copy = ModelEngine.clone(model);
    ModelEngine.setCollapsed(copy.root, collapsed); copy.root.collapsed = false;
    return copy;
  }
  static rules(root: ConceptNode): ConceptRule[] {
    const rules: ConceptRule[] = [];
    ModelEngine.ruleWalk(root, [], '', rules);
    return rules;
  }
  private static ruleWalk(node: ConceptNode, inherited: string[], path: string, rules: ConceptRule[]): void {
    const conditions: string[] = inherited.slice();
    for (const attr of node.attributes) if (!conditions.includes(attr)) conditions.push(attr);
    const full: string = path ? path + ' / ' + node.name : node.name;
    if (node.children.length === 0) {
      if (conditions.length > 0) rules.push({ concept: node.name, nodeId: node.id, conditions: conditions, path: full });
    } else for (const child of node.children) ModelEngine.ruleWalk(child, conditions, full, rules);
  }
  static parseModels(json: string): ConceptModel[] {
    if (ModelEngine.utf8Bytes(json) > 4 * 1024 * 1024) throw new Error('文件过大，请选择不超过 4 MB 的模型');
    const parsed: ConceptModel[] = JSON.parse(json) as ConceptModel[];
    if (!Array.isArray(parsed) || parsed.length > 100) throw new Error('模型文件必须是模型数组（最多 100 个）');
    const ids: string[] = [];
    let count: number = 0;
    for (const model of parsed) {
      if (!model || typeof model.id !== 'string' || !model.id.trim() || model.id.length > 200 || ids.includes(model.id) ||
        typeof model.name !== 'string' || !model.name.trim() || model.name.length > 200 ||
        typeof model.description !== 'string' || model.description.length > 10000 ||
        typeof model.createdAt !== 'number' || !Number.isFinite(model.createdAt) || !model.root) {
        throw new Error('模型信息不完整或 ID 重复');
      }
      ids.push(model.id);
      count += ModelEngine.validateNode(model.root, [], 1);
      if (count > 3000) throw new Error('模型文件最多包含 3000 个节点');
    }
    return parsed;
  }
  private static utf8Bytes(value: string): number {
    let bytes: number = 0;
    for (let index: number = 0; index < value.length; index++) {
      const code: number = value.charCodeAt(index);
      if (code <= 0x7f) bytes++;
      else if (code <= 0x7ff) bytes += 2;
      else if (code >= 0xd800 && code <= 0xdbff && index + 1 < value.length &&
        value.charCodeAt(index + 1) >= 0xdc00 && value.charCodeAt(index + 1) <= 0xdfff) {
        bytes += 4;
        index++;
      } else bytes += 3;
      if (bytes > 4 * 1024 * 1024) return bytes;
    }
    return bytes;
  }
  private static validateNode(node: ConceptNode, ids: string[], depth: number): number {
    if (depth > 32) throw new Error('概念树不能超过 32 层');
    if (ids.length >= 3000) throw new Error('单个模型最多包含 3000 个节点');
    if (!node || typeof node.id !== 'string' || !node.id.trim() || node.id.length > 200 || ids.includes(node.id) || typeof node.name !== 'string' ||
      !node.name.trim() || node.name.length > 200 || typeof node.description !== 'string' ||
      node.description.length > 10000 ||
      typeof node.collapsed !== 'boolean' || !Array.isArray(node.children) || !Array.isArray(node.attributes) || node.attributes.length > 100) {
      throw new Error('节点格式不正确或 ID 重复');
    }
    ids.push(node.id);
    for (const attr of node.attributes) if (typeof attr !== 'string' || !attr.trim() || attr.length > 200) throw new Error('特征必须是非空文本');
    let count: number = 1;
    for (const child of node.children) { count += ModelEngine.validateNode(child, ids, depth + 1); if (count > 3000) throw new Error('节点数量过多'); }
    return count;
  }
}
