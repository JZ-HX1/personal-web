import { ConceptModel, ConceptNode, ConceptRule, ModelEngine } from './ModelEngine';

export interface DecisionAnswer {
  attribute: string;
  value: string;
}

export interface RuleMatch {
  rule: ConceptRule;
  status: string;
  matched: number;
  missing: string[];
}

export interface DecisionQuestion {
  attribute: string;
  yesCount: number;
  noCount: number;
}

export interface FactorRow {
  nodeId: string;
  concept: string;
  path: string;
  ownAttributes: string[];
  // Complete effective attributes, including this node and every ancestor.
  inheritedAttributes: string[];
  leaf: boolean;
}

export interface ConversionBundle {
  format: string;
  version: number;
  modelId: string;
  modelName: string;
  source: ConceptModel;
  attributes: string[];
  rows: FactorRow[];
  rules: ConceptRule[];
}

export class DecisionEngine {
  private static answerMap(answers: DecisionAnswer[]): Map<string, string> {
    const values: Map<string, string> = new Map<string, string>();
    for (const answer of answers) {
      if (answer.value === 'yes' || answer.value === 'no' || answer.value === 'unknown') {
        values.set(answer.attribute, answer.value);
      }
    }
    return values;
  }

  static evaluate(model: ConceptModel, answers: DecisionAnswer[]): RuleMatch[] {
    const values: Map<string, string> = DecisionEngine.answerMap(answers);
    const results: RuleMatch[] = [];
    for (const rule of ModelEngine.rules(model.root)) {
      let matched: number = 0;
      let excluded: boolean = false;
      const missing: string[] = [];
      for (const condition of rule.conditions) {
        const value: string | undefined = values.get(condition);
        if (value === 'yes') {
          matched += 1;
        } else if (value === 'no') {
          excluded = true;
        } else {
          missing.push(condition);
        }
      }
      const status: string = excluded ? 'excluded' : (missing.length === 0 ? 'matched' : 'pending');
      results.push({ rule: rule, status: status, matched: matched, missing: missing });
    }
    // Use stable insertion ordering explicitly, so equal scores follow tree order.
    const ordered: RuleMatch[] = [];
    for (const result of results) {
      let index: number = 0;
      while (index < ordered.length && !DecisionEngine.before(result, ordered[index])) {
        index += 1;
      }
      ordered.splice(index, 0, result);
    }
    return ordered;
  }

  private static before(first: RuleMatch, second: RuleMatch): boolean {
    const firstRank: number = first.status === 'matched' ? 0 : (first.status === 'pending' ? 1 : 2);
    const secondRank: number = second.status === 'matched' ? 0 : (second.status === 'pending' ? 1 : 2);
    if (firstRank !== secondRank) return firstRank < secondRank;
    return first.status === 'pending' && first.missing.length < second.missing.length;
  }

  static questions(model: ConceptModel): string[] {
    const attributes: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (const rule of ModelEngine.rules(model.root)) {
      for (const attribute of rule.conditions) {
        if (!seen.has(attribute)) {
          seen.add(attribute);
          attributes.push(attribute);
        }
      }
    }
    return attributes;
  }

  static nextQuestion(model: ConceptModel, answers: DecisionAnswer[]): DecisionQuestion | undefined {
    const values: Map<string, string> = DecisionEngine.answerMap(answers);
    const pending: RuleMatch[] = DecisionEngine.evaluate(model, answers)
      .filter((result: RuleMatch) => result.status === 'pending');
    if (pending.length === 0) return undefined;
    const counts: Map<string, number> = new Map<string, number>();
    for (const result of pending) {
      for (const attribute of result.rule.conditions) {
        const count: number | undefined = counts.get(attribute);
        counts.set(attribute, count === undefined ? 1 : count + 1);
      }
    }
    let best: DecisionQuestion | undefined = undefined;
    let bestDistance: number = pending.length + 1;
    for (const attribute of DecisionEngine.questions(model)) {
      // "unknown" is unanswered evidence, but has already been asked this session.
      if (values.has(attribute)) continue;
      const yesCount: number | undefined = counts.get(attribute);
      if (yesCount === undefined) continue;
      const distance: number = Math.abs(yesCount * 2 - pending.length);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = { attribute: attribute, yesCount: yesCount, noCount: pending.length - yesCount };
      }
    }
    return best;
  }

  static convert(model: ConceptModel): ConversionBundle {
    const rows: FactorRow[] = [];
    const attributes: string[] = [];
    DecisionEngine.factorWalk(model.root, [], '', rows, attributes, new Set<string>());
    return {
      format: 'intermodeller.conversion',
      version: 1,
      modelId: model.id,
      modelName: model.name,
      source: ModelEngine.clone(model),
      attributes: attributes,
      rows: rows,
      rules: ModelEngine.rules(model.root)
    };
  }

  private static factorWalk(node: ConceptNode, ancestors: string[], parentPath: string,
    rows: FactorRow[], attributes: string[], seen: Set<string>): void {
    const own: string[] = [];
    const inherited: string[] = ancestors.slice();
    for (const attribute of node.attributes) {
      if (!own.includes(attribute)) own.push(attribute);
      if (!inherited.includes(attribute)) inherited.push(attribute);
      if (!seen.has(attribute)) {
        seen.add(attribute);
        attributes.push(attribute);
      }
    }
    const path: string = parentPath ? parentPath + ' / ' + node.name : node.name;
    rows.push({
      nodeId: node.id,
      concept: node.name,
      path: path,
      ownAttributes: own,
      inheritedAttributes: inherited,
      leaf: node.children.length === 0
    });
    for (const child of node.children) {
      DecisionEngine.factorWalk(child, inherited, path, rows, attributes, seen);
    }
  }

  static explainNoResult(model: ConceptModel, answers: DecisionAnswer[]): string {
    const results: RuleMatch[] = DecisionEngine.evaluate(model, answers);
    if (results.length === 0) return '模型还没有可推理的规则，请先为概念添加特征。';
    if (results.some((result: RuleMatch) => result.status === 'matched')) {
      return '已有符合全部条件的概念；仍有待确认的规则时，可继续判断特征。';
    }
    if (results.every((result: RuleMatch) => result.status === 'excluded')) {
      return '所有规则均与至少一个“否”回答冲突，请检查回答或补充模型规则。';
    }
    if (!DecisionEngine.nextQuestion(model, answers)) {
      return '剩余规则仍有“不确定”的条件，请修改相关回答后继续推理。';
    }
    return '尚未确认所有规则条件，请继续回答特征问题。';
  }
}
