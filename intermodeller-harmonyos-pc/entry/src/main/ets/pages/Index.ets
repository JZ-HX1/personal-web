import { common } from '@kit.AbilityKit';
import { ModelBridge } from '../services/ModelBridge';
import { DecisionEngine, DecisionAnswer, RuleMatch, DecisionQuestion, ConversionBundle, FactorRow } from '../model/DecisionEngine';
import { ModelEngine, ConceptModel, ConceptNode, FlatNode, PositionedNode, TreeLayout, ConceptRule } from '../model/ModelEngine';

interface StorageResult { success: boolean; content: string; message: string; cancelled: boolean; recovered?: boolean; }
interface WorkspaceSnapshot { models: ConceptModel[]; activeId: string; selectedId: string; }

@Entry
@Component
struct Index {
  @State models: ConceptModel[] = ModelEngine.samples();
  @State activeId: string = 'demo-animal';
  @State selectedId: string = '';
  @State view: string = 'tree';
  @State query: string = '';
  @State outlineRows: FlatNode[] = [];
  @State rows: FlatNode[] = [];
  @State positions: PositionedNode[] = [];
  @State rules: ConceptRule[] = [];
  @State attrs: string[] = [];
  @State zoom: number = 1;
  @State panX: number = 0;
  @State panY: number = 0;
  @State viewportWidth: number = 700;
  @State viewportHeight: number = 500;
  @State draftName: string = '';
  @State draftDescription: string = '';
  @State draftAttrs: string = '';
  @State savedStatus: string = '本地工作空间';
  @State undoCount: number = 0;
  @State redoCount: number = 0;
  @State modal: string = '';
  @State modelName: string = '';
  @State modelDescription: string = '';
  @State decisionAnswers: DecisionAnswer[] = [];
  @State decisionResults: RuleMatch[] = [];
  @State decisionPrompt: string = '';
  @State decisionQuestion: string = '';
  @State decisionDependent: number = 0;
  @State exporting: boolean = false;
  @State answers: string[] = [];
  @State inspectorVisible: boolean = true;
  @State sidebarVisible: boolean = true;
  private bridge: ModelBridge = new ModelBridge();
  private storageAvailable: boolean = false;
  private canvasReady: boolean = false;
  private context2d: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private layout: TreeLayout = { nodes: [], width: 600, height: 400 };
  private undoStack: string[] = [];
  private redoStack: string[] = [];
  private saveTimer: number = -1;
  private startX: number = 0;
  private startY: number = 0;
  private rootWidth: number = 1280;
  private emptyModel: ConceptModel = ModelEngine.blank('未命名模型');

  aboutToAppear(): void {
    try {
      const host = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (host && host.filesDir) {
        this.bridge.initialize(host);
        const result: StorageResult = JSON.parse(this.bridge.loadModels()) as StorageResult;
        if (result.success) {
          if (result.content !== 'null') this.models = ModelEngine.parseModels(result.content);
          this.storageAvailable = true;
          this.savedStatus = result.recovered ? '已从最近备份恢复' : '所有更改已保存';
        } else this.savedStatus = result.message || '本地模型读取失败，原文件已保留';
      }
    } catch (error) { this.storageAvailable = false; this.savedStatus = '预览模式 · 示例数据'; }
    if (this.models.length > 0) {
      this.activeId = this.models[0].id;
      this.selectedId = this.model().root.children.length > 0 ? this.model().root.children[0].id : this.model().root.id;
    }
    this.refresh(true);
  }
  aboutToDisappear(): void {
    if (this.saveTimer >= 0) { clearTimeout(this.saveTimer); this.save(); }
  }
  private model(): ConceptModel { return this.models.find((m: ConceptModel) => m.id === this.activeId) || this.emptyModel; }
  private selected(): ConceptNode { return ModelEngine.find(this.model().root, this.selectedId) || this.model().root; }
  private color(depth: number): string { return ['#7961D6', '#6387D2', '#4CA293', '#BD955D', '#9C79BE', '#7189A7'][Math.min(depth, 5)]; }
  private toast(message: string): void {
    try { this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 }); } catch (error) { }
  }
  private remember(): void {
    const snapshot: WorkspaceSnapshot = { models: this.models, activeId: this.activeId, selectedId: this.selectedId };
    this.undoStack.push(JSON.stringify(snapshot));
    if (this.undoStack.length > 40) this.undoStack.shift();
    this.redoStack = []; this.undoCount = this.undoStack.length; this.redoCount = 0;
  }
  private refresh(resetDraft: boolean): void {
    this.layout = ModelEngine.layout(this.model().root);
    this.positions = this.models.length > 0 ? this.layout.nodes : [];
    this.outlineRows = this.models.length > 0 ? ModelEngine.flatten(this.model().root, this.query) : [];
    this.rows = this.models.length > 0 ? ModelEngine.all(this.model().root) : [];
    this.rules = this.models.length > 0 ? ModelEngine.rules(this.model().root) : [];
    const attrs: string[] = [];
    for (const row of this.rows) for (const attr of row.node.attributes) if (!attrs.includes(attr)) attrs.push(attr);
    this.attrs = attrs;
    this.decisionAnswers = this.decisionAnswers.filter((answer: DecisionAnswer) => attrs.includes(answer.attribute));
    this.updateDecision();
    if (resetDraft) {
      this.draftName = this.selected().name; this.draftDescription = this.selected().description;
      this.draftAttrs = this.selected().attributes.join('，');
    }
    this.draw();
  }
  private scheduleSave(): void {
    this.savedStatus = this.storageAvailable ? '正在保存…' : '预览模式 · 未写入磁盘';
    if (this.saveTimer >= 0) clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => { this.saveTimer = -1; this.save(); }, 550);
  }
  private save(): void {
    if (!this.storageAvailable) { this.toast('预览器显示示例数据；请在设备或模拟器上使用本地保存'); return; }
    const result: StorageResult = JSON.parse(this.bridge.saveModels(JSON.stringify(this.models))) as StorageResult;
    this.savedStatus = result.success ? '所有更改已保存' : '保存失败';
    if (!result.success) this.toast(result.message);
  }
  private commit(model: ConceptModel, selectedId: string = ''): boolean {
    const next: ConceptModel[] = this.models.map((m: ConceptModel) => m.id === model.id ? model : m);
    try { ModelEngine.parseModels(JSON.stringify(next)); }
    catch (error) { this.toast('更改超过模型容量或层级限制，请减少节点或特征'); return false; }
    this.remember();
    this.models = next;
    if (selectedId) this.selectedId = selectedId;
    this.refresh(true); this.scheduleSave(); return true;
  }
  private select(id: string): void { if (!this.applyDraft(false)) return; this.selectedId = id; this.refresh(true); }
  private selectModel(id: string): void {
    if (!this.applyDraft(false)) return; this.activeId = id; this.selectedId = this.model().root.id;
    this.query = ''; this.answers = []; this.decisionAnswers = []; this.refresh(true); this.fit();
  }
  private applyDraft(notify: boolean): boolean {
    if (this.models.length === 0) return true;
    if (!this.draftName.trim()) { this.toast('概念名称不能为空，请先补全名称'); return false; }
    if (this.draftName !== this.selected().name || this.draftDescription !== this.selected().description ||
      this.draftAttrs !== this.selected().attributes.join('，')) {
      const accepted: boolean = this.commit(ModelEngine.update(this.model(), this.selected().id, this.draftName,
        this.draftDescription, this.draftAttrs.split(/[,，\n]/)));
      if (notify && accepted) this.toast('节点属性已更新');
      return accepted;
    }
    return true;
  }
  private addNode(sibling: boolean): void {
    if (!this.applyDraft(false)) return;
    if (sibling && this.selected().id === this.model().root.id) { this.toast('根概念没有同级节点'); return; }
    if (this.rows.length >= 3000) { this.toast('一个模型最多包含 3000 个节点'); return; }
    const next: ConceptModel = ModelEngine.add(this.model(), this.selected().id, sibling);
    this.commit(next, ModelEngine.lastAddedId); this.inspectorVisible = true;
  }
  private undo(redo: boolean): void {
    const from: string[] = redo ? this.redoStack : this.undoStack;
    if (from.length === 0) return;
    const now: WorkspaceSnapshot = { models: this.models, activeId: this.activeId, selectedId: this.selectedId };
    const target: string | undefined = from.pop();
    if (!target) return;
    if (redo) this.undoStack.push(JSON.stringify(now)); else this.redoStack.push(JSON.stringify(now));
    const restored: WorkspaceSnapshot = JSON.parse(target) as WorkspaceSnapshot;
    this.models = restored.models; this.activeId = restored.activeId; this.selectedId = restored.selectedId;
    this.undoCount = this.undoStack.length; this.redoCount = this.redoStack.length;
    this.refresh(true); this.scheduleSave();
  }
  private fit(): void {
    this.zoom = Math.min(1, Math.max(0.2, Math.min((this.viewportWidth - 32) / this.layout.width,
      (this.viewportHeight - 70) / this.layout.height)));
    this.panX = (this.viewportWidth - this.layout.width * this.zoom) / 2;
    this.panY = (this.viewportHeight - this.layout.height * this.zoom) / 2 - 10; this.draw();
  }
  private changeZoom(delta: number): void {
    const next: number = Math.max(0.2, Math.min(2.5, this.zoom + delta));
    this.panX = this.viewportWidth / 2 - (this.viewportWidth / 2 - this.panX) * next / this.zoom;
    this.panY = this.viewportHeight / 2 - (this.viewportHeight / 2 - this.panY) * next / this.zoom;
    this.zoom = next; this.draw();
  }
  private draw(): void {
    if (!this.canvasReady) return;
    const ctx: CanvasRenderingContext2D = this.context2d;
    ctx.clearRect(0, 0, this.viewportWidth, this.viewportHeight);
    ctx.fillStyle = '#E0E2EB';
    for (let x: number = this.panX % 22; x < this.viewportWidth; x += 22) {
      for (let y: number = this.panY % 22; y < this.viewportHeight; y += 22) ctx.fillRect(x, y, 1.2, 1.2);
    }
    for (const child of this.positions) {
      const parent = this.positions.find((item: PositionedNode) => item.node.children.some((n: ConceptNode) => n.id === child.node.id));
      if (parent) {
        const x1: number = (parent.x + 156) * this.zoom + this.panX;
        const y1: number = (parent.y + 30) * this.zoom + this.panY;
        const x2: number = child.x * this.zoom + this.panX;
        const y2: number = (child.y + 30) * this.zoom + this.panY;
        ctx.beginPath(); ctx.moveTo(x1, y1); ctx.bezierCurveTo((x1 + x2) / 2, y1, (x1 + x2) / 2, y2, x2, y2);
        ctx.strokeStyle = this.color(child.depth); ctx.globalAlpha = 0.5; ctx.lineWidth = 1.7; ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;
  }
  private createModel(): void {
    if (!this.modelName.trim()) { this.toast('请输入模型名称'); return; }
    if (this.models.length >= 100) { this.toast('工作空间最多保存 100 个模型'); return; }
    this.remember(); const model: ConceptModel = ModelEngine.blank(this.modelName.trim());
    this.models = this.models.concat([model]); this.activeId = model.id; this.selectedId = model.root.id;
    this.modal = ''; this.query = ''; this.refresh(true); this.fit(); this.scheduleSave();
  }
  private removeSelected(): void {
    if (this.modal === 'deleteModel') {
      this.remember(); this.models = this.models.filter((m: ConceptModel) => m.id !== this.activeId);
      this.activeId = this.models.length > 0 ? this.models[0].id : ''; this.selectedId = this.model().root.id;
      this.refresh(true); this.scheduleSave();
    } else {
      const parent = ModelEngine.parent(this.model().root, this.selected().id);
      if (parent) this.commit(ModelEngine.remove(this.model(), this.selected().id), parent.id);
    }
    this.modal = '';
  }
  private async importModels(): Promise<void> {
    if (!this.applyDraft(false)) return;
    if (!this.storageAvailable) { this.toast('请在设备或模拟器上使用系统文件选择器'); return; }
    const result: StorageResult = JSON.parse(await this.bridge.importFile()) as StorageResult;
    if (result.cancelled) return;
    if (!result.success) { this.toast(result.message); return; }
    try {
      const bundle: ConversionBundle = JSON.parse(result.content) as ConversionBundle;
      const modelJson: string = bundle && bundle.format === 'intermodeller.conversion' && bundle.version === 1 && bundle.source ?
        JSON.stringify([bundle.source]) : result.content;
      const imported: ConceptModel[] = ModelEngine.parseModels(modelJson);
      if (imported.length === 0) { this.toast('文件中没有模型'); return; }
      const additions: ConceptModel[] = imported.map((m: ConceptModel, index: number) => {
        const copy = ModelEngine.clone(m); copy.id = 'import-' + Date.now() + '-' + index; return copy;
      });
      ModelEngine.parseModels(JSON.stringify(this.models.concat(additions)));
      this.remember();
      this.models = this.models.concat(additions); this.selectModel(additions[0].id); this.scheduleSave();
      this.toast('已导入 ' + imported.length + ' 个模型');
    } catch (error) { this.toast('模型文件格式不正确，未修改现有模型'); }
  }
  private async exportModel(): Promise<void> {
    if (!this.applyDraft(false)) return;
    if (!this.storageAvailable) { this.toast('请在设备或模拟器上导出文件'); return; }
    const result: StorageResult = JSON.parse(await this.bridge.exportFile(JSON.stringify([this.model()], null, 2), this.model().name, 'json')) as StorageResult;
    if (!result.cancelled) this.toast(result.success ? '模型已导出' : result.message);
  }
  private async exportConversion(): Promise<void> {
    if (!this.applyDraft(false)) return;
    if (!this.storageAvailable) { this.toast('请在设备或模拟器上导出文件'); return; }
    const bundle: ConversionBundle = DecisionEngine.convert(this.model());
    const result: StorageResult = JSON.parse(await this.bridge.exportFile(JSON.stringify(bundle, null, 2),
      this.model().name + '-conversion', 'json')) as StorageResult;
    if (!result.cancelled) this.toast(result.success ? '转换包已导出' : result.message);
  }
  private updateDecision(): void {
    this.decisionResults = DecisionEngine.evaluate(this.model(), this.decisionAnswers);
    const question: DecisionQuestion | undefined = DecisionEngine.nextQuestion(this.model(), this.decisionAnswers);
    if (question) {
      this.decisionQuestion = question.attribute;
      this.decisionPrompt = '请判断特征：' + question.attribute;
      this.decisionDependent = question.yesCount;
    } else {
      this.decisionQuestion = '';
      this.decisionPrompt = this.decisionResults.some((item: RuleMatch) => item.status === 'matched') ?
        '已找到符合条件的概念' : '当前没有需要继续回答的特征';
      this.decisionDependent = 0;
    }
  }
  private answerDecision(attribute: string, value: string): void {
    this.decisionAnswers = this.decisionAnswers.filter((answer: DecisionAnswer) => answer.attribute !== attribute)
      .concat([{ attribute: attribute, value: value }]);
    this.updateDecision();
  }
  private clearDecision(): void {
    this.decisionAnswers = [];
    this.updateDecision();
  }
  private decisionStatus(result: RuleMatch): string {
    if (result.status === 'matched') return '已匹配';
    if (result.status === 'excluded') return '已排除';
    return '待确认 ' + result.missing.length + ' 项';
  }
  private matched(rule: ConceptRule): number { return rule.conditions.filter((attr: string) => this.answers.includes(attr)).length; }
  private toggleAnswer(attr: string): void { this.answers = this.answers.includes(attr) ? this.answers.filter((a: string) => a !== attr) : this.answers.concat([attr]); }

  @Builder
  private iconButton(icon: Resource, caption: string, action: () => void, enabled: boolean = true) {
    Button({ type: ButtonType.Normal }) { Image(icon).width(18).height(18) }
      .width(32).height(32).borderRadius(7).backgroundColor(Color.Transparent)
      .hoverEffect(HoverEffect.Highlight)
      .enabled(caption === '撤销' ? this.undoCount > 0 : caption === '重做' ? this.redoCount > 0 : enabled)
      .opacity((caption === '撤销' ? this.undoCount > 0 : caption === '重做' ? this.redoCount > 0 : enabled) ? 1 : 0.35)
      .accessibilityText(caption).onClick(action)
  }
  @Builder
  private action(icon: Resource, caption: string, callback: () => void, primary: boolean = false) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 7 }) {
        Image(icon).width(16).height(16).fillColor(primary ? '#FFFFFF' : '#687087')
        Text(caption).fontSize(12).fontWeight(500).fontColor(primary ? '#FFFFFF' : '#47516A')
      }
    }.height(34).padding({ left: 13, right: 13 }).borderRadius(7)
      .backgroundColor(primary ? '#7961D6' : '#FFFFFF')
      .border({ width: primary ? 0 : 1, color: '#E5E7EE' }).onClick(callback)
  }
  @Builder
  private header() {
    Row({ space: 12 }) {
      Image($r('app.media.im_logo')).width(32).height(32)
      Text('InterModeller').fontSize(19).fontWeight(600).fontColor('#283149')
      Text('概念建模').fontSize(11).fontColor('#8D95A7').margin({ left: 2, right: 22 })
      Text('文件').fontSize(13).fontColor('#657087').padding(8)
        .bindMenu([{ value: '新建模型', action: () => { this.modelName = ''; this.modal = 'new'; } },
          { value: '导入 JSON', action: () => { this.importModels(); } },
          { value: '导出当前模型', action: () => { this.exportModel(); } },
          { value: '保存全部模型', action: () => { if (this.applyDraft(false)) this.save(); } }])
      Text('编辑').fontSize(13).fontColor('#657087').padding(8)
        .bindMenu([{ value: '撤销', action: () => this.undo(false) }, { value: '重做', action: () => this.undo(true) },
          { value: '添加子概念', action: () => this.addNode(false) }])
      Text('视图').fontSize(13).fontColor('#657087').padding(8)
        .bindMenu([{ value: '分类树', action: () => { this.view = 'tree'; } },
          { value: '决策树', action: () => { if (this.applyDraft(false)) { this.view = 'decision'; this.updateDecision(); } } },
          { value: '因子表', action: () => { this.view = 'table'; } },
          { value: '规则', action: () => { this.view = 'rules'; } },
          { value: '切换模型侧栏', action: () => { this.sidebarVisible = !this.sidebarVisible; } },
          { value: '切换属性面板', action: () => { this.inspectorVisible = !this.inspectorVisible; } }])
      Blank()
      Row({ space: 7 }) {
        Row().width(6).height(6).backgroundColor('#64AB97').borderRadius(3)
        Text('本地工作空间').fontSize(11).fontColor('#818A9C')
      }
      Button({ type: ButtonType.Normal }) { Image($r('app.media.im_save')).width(17).height(17) }
        .height(32).width(32).backgroundColor(Color.Transparent).borderRadius(7).accessibilityText('保存 Ctrl+S')
        .onClick(() => { if (this.applyDraft(false)) this.save(); })
        .keyboardShortcut('s', [ModifierKey.CTRL], () => { if (this.applyDraft(false)) this.save(); })
      this.iconButton($r('app.media.im_help'), '使用帮助', () => { this.modal = 'help'; })
      Text('IM').fontSize(11).fontWeight(600).fontColor('#8A73CA').width(30).height(30)
        .textAlign(TextAlign.Center).backgroundColor('#F1ECFA').borderRadius(15)
    }.height(62).width('100%').padding({ left: 22, right: 22 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E8E9F0' })
  }
  @Builder
  private sidebar() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.im_layers')).width(21).height(21).fillColor('#7961D6')
        Column({ space: 3 }) {
          Text('我的工作空间').fontSize(13).fontWeight(600).fontColor('#333D54')
          Text('让知识之间的联系清晰可见').fontSize(10).fontColor('#969CAD')
        }.alignItems(HorizontalAlign.Start)
      }.width('100%').padding({ top: 23, bottom: 22, left: 18 })
      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          Image($r('app.media.im_plus')).width(16).height(16).fillColor('#7961D6')
          Text('新建概念模型').fontSize(12).fontWeight(500).fontColor('#7961D6')
        }
      }.height(36).width('84%').backgroundColor('#ECE7F9').borderRadius(7)
        .onClick(() => { this.modelName = ''; this.modal = 'new'; })
      Row() {
        Text('模型库').fontSize(10).fontWeight(600).fontColor('#9A9FB0').letterSpacing(1)
        Blank()
        Text(this.models.length.toString()).fontSize(10).fontColor('#A2A7B6')
      }.padding({ left: 20, right: 21, top: 25, bottom: 10 }).width('100%')
      Scroll() {
        Column({ space: 4 }) {
          ForEach(this.models, (m: ConceptModel) => {
            Row({ space: 10 }) {
              Image($r('app.media.im_document')).width(16).height(16)
                .fillColor(m.id === this.activeId ? '#7961D6' : '#989EB0')
              Text(m.name).fontSize(12).fontWeight(m.id === this.activeId ? 600 : 400)
                .fontColor(m.id === this.activeId ? '#7961D6' : '#677188').layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(ModelEngine.all(m.root).length.toString()).fontSize(10).fontColor('#A1A6B5')
            }.height(35).width('100%').padding({ left: 12, right: 12 }).borderRadius(7)
              .backgroundColor(m.id === this.activeId ? '#EDE8F8' : Color.Transparent)
              .onClick(() => this.selectModel(m.id))
          }, (m: ConceptModel) => m.id + m.name + ModelEngine.all(m.root).length)
        }.width('100%')
      }.width('100%').constraintSize({ maxHeight: 225 }).padding({ left: 11, right: 11 }).scrollBar(BarState.Auto)
      Divider().color('#E7E8EF').margin({ top: 20, bottom: 19 }).width('84%')
      Row() {
        Text('模型大纲').fontSize(10).fontWeight(600).fontColor('#9A9FB0').letterSpacing(1)
        Blank()
        Text(this.rows.length + ' 个概念').fontSize(10).fontColor('#A2A7B6')
      }.padding({ left: 20, right: 20, bottom: 12 }).width('100%')
      Row({ space: 7 }) {
        Image($r('app.media.im_search')).width(14).height(14)
        TextInput({ text: this.query, placeholder: '搜索概念或特征' }).fontSize(11).height(30)
          .backgroundColor(Color.Transparent).padding(0).layoutWeight(1)
          .onChange((value: string) => { this.query = value; this.outlineRows = ModelEngine.flatten(this.model().root, value); })
      }.width('84%').height(32).padding({ left: 10, right: 8 }).backgroundColor('#FFFFFF').borderRadius(6)
        .border({ width: 1, color: '#E7E8EE' }).margin({ bottom: 10 })
      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.outlineRows, (row: FlatNode) => {
            Row({ space: 6 }) {
              if (row.node.children.length > 0) {
                Image(row.node.collapsed ? $r('app.media.im_chevron_right') : $r('app.media.im_chevron_down'))
                  .width(12).height(12).onClick(() => this.commit(ModelEngine.collapse(this.model(), row.node.id)))
              } else { Row().width(4).height(4).backgroundColor(this.color(row.depth)).borderRadius(2).margin({ left: 4, right: 4 }) }
              Text(row.node.name).fontSize(11).fontColor(row.node.id === this.selectedId ? '#7961D6' : '#6A7489')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            }.height(29).width('100%').padding({ left: 10 + Math.min(row.depth, 5) * 12, right: 8 })
              .backgroundColor(row.node.id === this.selectedId ? '#F0ECF9' : Color.Transparent).borderRadius(5)
              .onClick(() => this.select(row.node.id))
          }, (row: FlatNode) => row.node.id + row.node.name + row.node.collapsed + row.node.children.length)
          if (this.outlineRows.length === 0) { Text('没有找到匹配的概念').fontSize(11).fontColor('#969CAD').padding(20) }
        }.width('100%')
      }.layoutWeight(1).width('100%').padding({ left: 10, right: 10 }).scrollBar(BarState.Auto)
      Row({ space: 9 }) {
        Image($r('app.media.im_help')).width(16).height(16)
        Text('使用指南与快捷操作').fontSize(11).fontColor('#9298AA')
      }.width('100%').padding(19).onClick(() => { this.modal = 'help'; })
    }.width(228).height('100%').backgroundColor('#F7F8FC')
      .border({ width: { right: 1 }, color: '#E8E9F0' })
  }
  @Builder
  private heading() {
    Row({ space: 14 }) {
      Image($r('app.media.im_tree')).width(24).height(24).fillColor('#8B74CC')
        .padding(10).width(46).height(46).backgroundColor('#F0EBFA').borderRadius(12)
      Column({ space: 7 }) {
        Row({ space: 10 }) {
          Text(this.model().name).fontSize(24).fontWeight(600).fontColor('#2E374F')
          Text('分类模型').fontSize(9).fontColor('#8F7AC1').padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .backgroundColor('#F1EDFA').borderRadius(4)
        }
        Text(this.model().description || '从一个概念开始，构建你的知识模型').fontSize(11).fontColor('#9299AA').maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      this.action($r('app.media.im_import'), '导入', () => { this.importModels(); })
      this.action($r('app.media.im_export'), '转换 / 导出', () => { if (this.applyDraft(false)) this.modal = 'convert'; })
      this.iconButton($r('app.media.im_more'), '模型选项', () => { this.modal = 'modelOptions'; })
    }.height(100).width('100%').padding({ left: 28, right: 24 }).backgroundColor('#FFFFFF')
  }
  @Builder
  private viewTab(value: string, title: string, icon: Resource) {
    Row({ space: 7 }) {
      Image(icon).width(16).height(16).fillColor(this.view === value ? '#7961D6' : '#9097A9')
      Text(title).fontSize(12).fontWeight(this.view === value ? 600 : 400).fontColor(this.view === value ? '#7961D6' : '#858DA0')
    }.height(45).padding({ left: 15, right: 15 }).margin({ right: 8 })
      .border({ width: { bottom: this.view === value ? 2 : 0 }, color: '#7961D6' })
      .onClick(() => { if (!this.applyDraft(false)) return; this.view = value; if (value === 'tree') this.draw(); })
  }
  @Builder
  private editingToolbar() {
    Row({ space: 6 }) {
      this.action($r('app.media.im_plus_white'), '子概念', () => this.addNode(false), true)
      this.action($r('app.media.im_plus'), '同级概念', () => this.addNode(true))
      Divider().vertical(true).height(19).color('#E5E7EF').margin({ left: 9, right: 8 })
      this.iconButton($r('app.media.im_undo'), '撤销', () => this.undo(false), this.undoCount > 0)
      this.iconButton($r('app.media.im_redo'), '重做', () => this.undo(true), this.redoCount > 0)
      Blank()
      this.iconButton($r('app.media.im_layers'), '全部展开', () => { this.commit(ModelEngine.expandAll(this.model(), false)); this.fit(); })
      this.iconButton($r('app.media.im_folder'), '折叠分支', () => { this.commit(ModelEngine.expandAll(this.model(), true)); this.fit(); })
      this.iconButton($r('app.media.im_settings'), '切换属性面板', () => { this.inspectorVisible = !this.inspectorVisible; })
    }.height(56).width('100%').padding({ left: 24, right: 22 }).backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#E8E9F0' })
  }
  @Builder
  private nodeCard(item: PositionedNode) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 6 * this.zoom }) {
        Row({ space: 7 * this.zoom }) {
          Row().width(6 * this.zoom).height(6 * this.zoom).backgroundColor(item.depth === 0 ? '#DCD2F5' : this.color(item.depth)).borderRadius(4)
          Text(item.node.name).fontSize(Math.max(10, 14 * this.zoom)).fontWeight(600)
            .fontColor(item.depth === 0 ? '#FFFFFF' : '#414D65').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }.width('100%')
        Text(item.node.attributes.length > 0 ? item.node.attributes.slice(0, 2).join(' · ') :
          (item.node.children.length > 0 ? item.node.children.length + ' 个子概念' : '实例概念'))
          .fontSize(Math.max(8, 10 * this.zoom)).fontColor(item.depth === 0 ? '#DED5F5' : '#9BA2B2').maxLines(1)
      }.alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
        .width(156 * this.zoom).height(60 * this.zoom).padding({ left: 13 * this.zoom, right: 12 * this.zoom })
        .backgroundColor(item.depth === 0 ? '#7961D6' : '#FFFFFF').borderRadius(9 * this.zoom)
        .border({ width: item.node.id === this.selectedId ? 2 : 1, color: item.node.id === this.selectedId ? '#9B82DF' : (item.depth === 0 ? '#7961D6' : '#E5E7F0') })
        .shadow({ radius: 6, color: '#0A4B416F', offsetY: 2 }).onClick(() => this.select(item.node.id))
      if (item.node.children.length > 0) {
        Text(item.node.collapsed ? '+' : '−').fontSize(11).fontColor('#9888B9').textAlign(TextAlign.Center)
          .width(18 * this.zoom).height(18 * this.zoom).backgroundColor('#FFFFFF').borderRadius(10)
          .border({ width: 1, color: '#E2DCEF' }).position({ x: 147 * this.zoom, y: 21 * this.zoom })
          .onClick(() => this.commit(ModelEngine.collapse(this.model(), item.node.id)))
      }
    }.width(166 * this.zoom).height(60 * this.zoom)
      .position({ x: item.x * this.zoom + this.panX, y: item.y * this.zoom + this.panY })
  }
  @Builder
  private graph() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context2d).width('100%').height('100%')
        .onReady(() => { this.canvasReady = true; this.fit(); })
        .gesture(PanGesture({ direction: PanDirection.All, distance: 2 })
          .onActionStart(() => { this.startX = this.panX; this.startY = this.panY; })
          .onActionUpdate((event: GestureEvent) => { this.panX = this.startX + event.offsetX; this.panY = this.startY + event.offsetY; this.draw(); }))
      ForEach(this.positions, (item: PositionedNode) => { this.nodeCard(item) },
        (item: PositionedNode) => item.node.id + item.x + item.y + item.node.name + item.node.attributes.join(',') + item.node.collapsed + item.node.children.length)
      Row({ space: 3 }) {
        this.iconButton($r('app.media.im_zoom_out'), '缩小', () => this.changeZoom(-0.1))
        Text(Math.round(this.zoom * 100) + '%').fontSize(11).fontColor('#6D7489').width(41).textAlign(TextAlign.Center)
          .onClick(() => this.changeZoom(1 - this.zoom))
        this.iconButton($r('app.media.im_zoom_in'), '放大', () => this.changeZoom(0.1))
        Divider().vertical(true).height(17).color('#E7E8EF').margin({ left: 5, right: 5 })
        this.iconButton($r('app.media.im_fit'), '适应画布', () => this.fit())
      }.padding(5).borderRadius(9).backgroundColor('#FFFFFF').border({ width: 1, color: '#E7E8EF' })
        .position({ x: Math.max(15, this.viewportWidth - 212), y: Math.max(10, this.viewportHeight - 62) })
      Row({ space: 7 }) {
        Image($r('app.media.im_info')).width(13).height(13)
        Text('点击概念编辑属性 · 拖动画布平移').fontSize(10).fontColor('#A1A7B6')
      }.position({ x: 22, y: Math.max(10, this.viewportHeight - 42) })
    }.width('100%').layoutWeight(1).backgroundColor('#FAFBFE').clip(true)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        const w: number = Number(newArea.width); const h: number = Number(newArea.height);
        if (w !== this.viewportWidth || h !== this.viewportHeight) { this.viewportWidth = w; this.viewportHeight = h; this.fit(); }
      })
  }
  @Builder
  private decisionView() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 7 }) {
          Text('规则决策树').fontSize(18).fontWeight(600).fontColor('#354057')
          Text('沿特征逐步判断，查看最可能的分类结果').fontSize(11).fontColor('#9199AB')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        this.action($r('app.media.im_close'), '清空回答', () => this.clearDecision())
      }.width('100%')
      Column({ space: 10 }) {
        Text(this.decisionPrompt).fontSize(14).fontWeight(600).fontColor('#4E5B73').width('100%')
        Text(this.decisionDependent > 0 ? '这个特征会影响 ' + this.decisionDependent + ' 条待确认规则' :
          DecisionEngine.explainNoResult(this.model(), this.decisionAnswers))
          .fontSize(11).fontColor('#929AAB').width('100%').lineHeight(18)
        if (this.decisionQuestion.length > 0) {
          Row({ space: 8 }) {
            Button('是', { type: ButtonType.Normal }).height(34).layoutWeight(1).fontSize(12).fontColor('#FFFFFF')
              .backgroundColor('#5D9E8D').borderRadius(7).onClick(() => this.answerDecision(this.decisionQuestion, 'yes'))
            Button('否', { type: ButtonType.Normal }).height(34).layoutWeight(1).fontSize(12).fontColor('#FFFFFF')
              .backgroundColor('#C6848E').borderRadius(7).onClick(() => this.answerDecision(this.decisionQuestion, 'no'))
            Button('不确定', { type: ButtonType.Normal }).height(34).layoutWeight(1).fontSize(12).fontColor('#59657B')
              .backgroundColor('#F0F1F6').borderRadius(7).onClick(() => this.answerDecision(this.decisionQuestion, 'unknown'))
          }.width('100%')
        }
      }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(9)
        .border({ width: 1, color: '#E7E9F0' }).alignItems(HorizontalAlign.Start)
      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.decisionResults, (result: RuleMatch) => {
            Row({ space: 10 }) {
              Column({ space: 5 }) {
                Text(result.rule.concept).fontSize(13).fontWeight(600).fontColor('#4A5670')
                Text(result.rule.path).fontSize(10).fontColor('#A0A7B7').maxLines(1)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(this.decisionStatus(result)).fontSize(10).fontColor(result.status === 'matched' ? '#4E9C89' :
                result.status === 'excluded' ? '#B97883' : '#A28B5A')
            }.width('100%').padding(15).backgroundColor('#FFFFFF').borderRadius(8)
              .border({ width: 1, color: '#E7E9F0' }).onClick(() => this.select(result.rule.nodeId))
          }, (result: RuleMatch) => result.rule.nodeId + result.status + result.missing.join(','))
          if (this.decisionResults.length === 0) {
            Text('当前模型还没有可推理的末级规则。为末级概念添加特征后，这里会自动生成决策路径。')
              .fontSize(12).fontColor('#969EAF').padding(30).width('100%')
          }
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
    }.width('100%').layoutWeight(1).padding(25).backgroundColor('#FAFBFE')
  }
  @Builder
  private factorTable() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 7 }) {
          Text('概念因子表').fontSize(18).fontWeight(600).fontColor('#354057')
          Text('对照各概念的特征属性，检查分类依据').fontSize(11).fontColor('#9199AB')
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.rows.length + ' 个概念 / ' + this.attrs.length + ' 项特征').fontSize(11).fontColor('#8B77BE')
      }.width('100%')
      if (this.attrs.length === 0) {
        Column({ space: 12 }) {
          Image($r('app.media.im_grid')).width(36).height(36).opacity(0.5)
          Text('还没有特征属性').fontSize(15).fontColor('#6A7388')
          Text('在右侧为概念添加特征，因子表会自动生成').fontSize(11).fontColor('#9BA2B3')
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Scroll() {
          Column() {
            Row() {
              Text('概念 / 分类路径').fontSize(11).fontWeight(600).fontColor('#81899D').width(240).padding(14)
              ForEach(this.attrs, (attr: string) => {
                Text(attr).fontSize(11).fontWeight(500).fontColor('#81899D').width(90).textAlign(TextAlign.Center).maxLines(2)
              }, (attr: string) => attr)
            }.height(45).backgroundColor('#F2F3F8').width(240 + this.attrs.length * 90)
            ForEach(this.rows, (row: FlatNode) => {
              Row() {
                Column({ space: 5 }) {
                  Text(row.node.name).fontSize(12).fontWeight(500).fontColor('#48546D')
                  Text(row.path).fontSize(9).fontColor('#A0A6B6').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width(240).alignItems(HorizontalAlign.Start).padding({ left: 14, right: 12 })
                ForEach(this.attrs, (attr: string) => {
                  Text(row.node.attributes.includes(attr) ? '✓' : '—').fontSize(13)
                    .fontColor(row.node.attributes.includes(attr) ? '#52A38E' : '#D1D5DF').width(90).textAlign(TextAlign.Center)
                }, (attr: string) => attr)
              }.height(58).width(240 + this.attrs.length * 90)
                .backgroundColor(row.node.id === this.selectedId ? '#F5F1FC' : '#FFFFFF')
                .border({ width: { bottom: 1 }, color: '#EDEEF3' }).onClick(() => this.select(row.node.id))
            }, (row: FlatNode) => row.node.id + row.node.name + row.path + row.node.attributes.join(','))
          }.width(240 + this.attrs.length * 90)
          }.scrollable(ScrollDirection.Vertical).width(240 + this.attrs.length * 90).height('100%')
        }.scrollable(ScrollDirection.Horizontal).layoutWeight(1).width('100%').borderRadius(8)
          .border({ width: 1, color: '#E7E9F0' }).align(Alignment.TopStart)
      }
    }.width('100%').layoutWeight(1).padding(25).backgroundColor('#FAFBFE')
  }
  @Builder
  private ruleCard(rule: ConceptRule, index: number) {
    Column({ space: 13 }) {
      Row() {
        Text('规则 ' + (index + 1).toString().padStart(2, '0')).fontSize(10).fontWeight(600).fontColor('#A0A6B6')
        Blank()
        Text(rule.conditions.length + ' 个条件').fontSize(10).fontColor('#A1A7B7')
      }.width('100%')
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        Text('IF').fontSize(11).fontWeight(600).fontColor('#8C82A2').margin({ right: 10, bottom: 6 })
        ForEach(rule.conditions, (attr: string, idx: number) => {
          if (idx > 0) { Text('AND').fontSize(9).fontColor('#B4B8C5').margin({ right: 7, bottom: 6 }) }
          Text(attr).fontSize(11).fontColor('#5C9C90').padding({ left: 7, right: 7, top: 4, bottom: 4 })
            .backgroundColor('#EDF7F3').borderRadius(4).margin({ right: 7, bottom: 6 })
        }, (attr: string) => attr)
      }
      Row({ space: 9 }) {
        Text('THEN').fontSize(11).fontWeight(600).fontColor('#8C82A2')
        Text(rule.concept).fontSize(14).fontWeight(600).fontColor('#7961D6')
        Blank()
        Image($r('app.media.im_chevron_right')).width(14).height(14).opacity(0.5)
      }.width('100%')
      Text(rule.path).fontSize(10).fontColor('#A5ABBA').maxLines(1)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(9)
      .backgroundColor('#FFFFFF').border({ width: 1, color: '#E7E9F0' }).margin({ bottom: 12 })
      .onClick(() => this.select(rule.nodeId))
  }
  @Builder
  private rulesView() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 7 }) {
          Text('从概念到规则').fontSize(18).fontWeight(600).fontColor('#354057')
          Text('沿分类路径累积特征，为每个末级概念生成 IF–THEN 规则').fontSize(11).fontColor('#9199AB')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        this.action($r('app.media.im_target_white'), '尝试推理', () => { this.answers = []; this.modal = 'infer'; }, true)
      }.width('100%')
      Scroll() {
        Column() {
          ForEach(this.rules, (rule: ConceptRule, index: number) => { this.ruleCard(rule, index) },
            (rule: ConceptRule) => rule.nodeId + rule.concept + rule.path + rule.conditions.join(','))
          if (this.rules.length === 0) { Text('为概念添加特征后，即可生成分类规则').fontSize(13).fontColor('#969EAF').padding(50) }
        }.width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto).align(Alignment.TopStart)
    }.width('100%').layoutWeight(1).padding(25).backgroundColor('#FAFBFE')
  }
  @Builder
  private inspector() {
    Column() {
      Row({ space: 8 }) {
        Image($r('app.media.im_settings')).width(16).height(16).fillColor('#8D7CB5')
        Text('节点属性').fontSize(12).fontWeight(600).fontColor('#525E75')
        Blank()
        this.iconButton($r('app.media.im_close'), '关闭属性面板', () => { this.applyDraft(false); this.inspectorVisible = false; })
      }.height(49).width('100%').padding({ left: 20, right: 9 }).border({ width: { bottom: 1 }, color: '#ECEEF3' })
      Scroll() {
        Column({ space: 15 }) {
          Row({ space: 10 }) {
            Image($r('app.media.im_document')).width(20).height(20).fillColor('#8B73C7')
              .padding(10).width(40).height(40).backgroundColor('#F1EDFA').borderRadius(10)
            Column({ space: 6 }) {
              Text(this.selected().name).fontSize(15).fontWeight(600).fontColor('#3F4961').maxLines(2)
              Text(this.selected().children.length > 0 ? '分类概念' : '末级概念').fontSize(10).fontColor('#9AA1B2')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%').margin({ top: 7, bottom: 10 })
          Text('概念名称').fontSize(11).fontWeight(500).fontColor('#818A9E').width('100%')
          TextInput({ text: this.draftName, placeholder: '输入概念名称' }).fontSize(12).height(37)
            .backgroundColor('#FAFBFD').borderRadius(6).border({ width: 1, color: '#E6E8EF' }).maxLength(200)
            .onChange((value: string) => { this.draftName = value; })
          Text('描述').fontSize(11).fontWeight(500).fontColor('#818A9E').width('100%').margin({ top: 4 })
          TextArea({ text: this.draftDescription, placeholder: '这个概念有什么特点？' }).fontSize(12).height(88)
            .backgroundColor('#FAFBFD').borderRadius(6).border({ width: 1, color: '#E6E8EF' }).maxLength(1000)
            .onChange((value: string) => { this.draftDescription = value; })
          Row() {
            Text('特征属性').fontSize(11).fontWeight(500).fontColor('#818A9E')
            Blank()
            Text(this.selected().attributes.length + ' 项').fontSize(10).fontColor('#AFB4C1')
          }.width('100%').margin({ top: 4 })
          TextArea({ text: this.draftAttrs, placeholder: '例如：温血，胎生，哺乳' }).fontSize(12).height(72)
            .backgroundColor('#FAFBFD').borderRadius(6).border({ width: 1, color: '#E6E8EF' }).maxLength(2000)
            .onChange((value: string) => { this.draftAttrs = value; })
          Text('使用逗号分隔多个特征，规则将自动继承父级特征。').fontSize(10).fontColor('#ADB2C0').lineHeight(17).width('100%')
          Button('应用更改', { type: ButtonType.Normal }).fontSize(12).fontWeight(500).fontColor('#FFFFFF')
            .height(35).width('100%').backgroundColor('#7961D6').borderRadius(6).onClick(() => this.applyDraft(true))
          Divider().color('#ECEEF4').margin({ top: 10, bottom: 4 })
          Row() { Text('直接子概念').fontSize(11).fontColor('#979FB1'); Blank(); Text(this.selected().children.length.toString()).fontSize(11).fontColor('#65728A') }.width('100%')
          Row() { Text('层级路径').fontSize(11).fontColor('#979FB1'); Blank() }.width('100%')
          Text((this.rows.find((row: FlatNode) => row.node.id === this.selectedId)?.path) || this.model().root.name)
            .fontSize(10).fontColor('#9BA3B4').lineHeight(18).width('100%')
          Row({ space: 7 }) {
            Image($r('app.media.im_trash')).width(14).height(14).fillColor('#C68C96')
            Text('删除此概念').fontSize(11).fontColor('#C68C96')
          }.height(32).opacity(this.selected().id === this.model().root.id ? 0.35 : 1)
            .onClick(() => { if (this.selected().id !== this.model().root.id) this.modal = 'deleteNode'; })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 21, right: 21, bottom: 20 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.TopStart)
      Row({ space: 7 }) {
        Image($r('app.media.im_info')).width(13).height(13).opacity(0.65)
        Text('好模型，从清晰的概念开始').fontSize(10).fontColor('#A2A9B9')
      }.height(49).width('100%').padding({ left: 20 }).backgroundColor('#FBFCFE')
    }.width(270).height('100%').backgroundColor('#FFFFFF').border({ width: { left: 1 }, color: '#E8E9F0' })
  }
  @Builder
  private inference() {
    Text('选择已观察到的特征').fontSize(13).fontWeight(600).fontColor('#58647C').width('100%')
    Text('未选择的特征视为未知。条件全部满足时显示匹配结果，可能出现多个结果。')
      .fontSize(11).fontColor('#969FB1').lineHeight(18).width('100%').margin({ top: 6, bottom: 13 })
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.attrs, (attr: string) => {
        Text((this.answers.includes(attr) ? '✓ ' : '') + attr).fontSize(11)
          .fontColor(this.answers.includes(attr) ? '#7961D6' : '#8993A7').padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .backgroundColor(this.answers.includes(attr) ? '#F0EAFB' : '#F6F7FA').borderRadius(5).margin({ right: 8, bottom: 8 })
          .onClick(() => this.toggleAnswer(attr))
      }, (attr: string) => attr)
    }.width('100%')
    Divider().color('#E9EBF2').margin({ top: 10, bottom: 16 })
    Text('推理结果').fontSize(13).fontWeight(600).fontColor('#58647C').width('100%').margin({ bottom: 13 })
    if (this.answers.length === 0) {
      Text('选择特征后查看规则匹配情况').fontSize(12).fontColor('#A0A7B7').padding({ top: 20, bottom: 20 })
    } else {
      ForEach(this.rules, (rule: ConceptRule) => {
        Row({ space: 10 }) {
          Text(rule.concept).fontSize(12).fontWeight(500).fontColor('#68748B').layoutWeight(1)
          Text(this.matched(rule) === rule.conditions.length ? '✓ 条件全部满足' : '待补充 ' + (rule.conditions.length - this.matched(rule)) + ' 个条件')
            .fontSize(10).fontColor(this.matched(rule) === rule.conditions.length ? '#52A38D' : '#A2A9B9')
        }.width('100%').padding({ top: 9, bottom: 9 }).border({ width: { bottom: 1 }, color: '#F0F1F5' })
      }, (rule: ConceptRule) => rule.nodeId)
    }
  }
  @Builder
  private dialog() {
    Column() {
      Row() {
        Text(this.modal === 'new' ? '新建概念模型' : this.modal === 'help' ? '开始使用 InterModeller' :
          this.modal === 'infer' ? '分类推理' : this.modal === 'modelOptions' ? '模型选项' :
            this.modal === 'convert' ? '模型转换与导出' : '确认删除')
          .fontSize(18).fontWeight(600).fontColor('#36415A')
        Blank()
        this.iconButton($r('app.media.im_close'), '关闭对话框', () => { this.modal = ''; })
      }.width('100%').padding({ left: 25, right: 18, top: 17, bottom: 17 })
      Divider().color('#E9EBF2')
      Scroll() {
        Column({ space: 12 }) {
          if (this.modal === 'new') {
            Text('把一个想法，整理成有结构的知识。').fontSize(12).fontColor('#949DAF').width('100%').margin({ bottom: 10 })
            Text('模型名称').fontSize(12).fontColor('#7F899E').width('100%')
            TextInput({ text: this.modelName, placeholder: '例如：校园植物分类' }).height(42).fontSize(13).maxLength(100)
              .backgroundColor('#F7F8FC').borderRadius(7).onChange((value: string) => { this.modelName = value; })
          } else if (this.modal === 'infer') {
            this.inference()
          } else if (this.modal === 'help') {
            Text('1  选择模型或创建空白模型').fontSize(13).fontColor('#66728B').width('100%')
            Text('左侧提供动物、交通、植物等六个示例。新建模型从一个根概念开始。').fontSize(12).fontColor('#9AA3B5').lineHeight(22).width('100%')
            Text('2  添加概念与特征').fontSize(13).fontColor('#66728B').width('100%').margin({ top: 12 })
            Text('选中节点后添加子概念或同级概念，在右侧编辑名称、描述和特征，再应用更改。可撤销、重做。').fontSize(12).fontColor('#9AA3B5').lineHeight(22).width('100%')
            Text('3  从不同角度检查模型').fontSize(13).fontColor('#66728B').width('100%').margin({ top: 12 })
            Text('分类树显示层级关系；因子表对照特征；规则从根到末级概念累积条件。推理面板可选择已知特征并查看匹配。').fontSize(12).fontColor('#9AA3B5').lineHeight(22).width('100%')
            Text('设备上自动保存到应用本地。JSON 导出可用于备份和交换，兼容原项目模型数组格式。').fontSize(12).fontColor('#9AA3B5').lineHeight(22).width('100%').margin({ top: 12 })
          } else if (this.modal === 'modelOptions') {
            this.action($r('app.media.im_export'), '导出当前模型', () => { this.modal = ''; this.exportModel(); })
            this.action($r('app.media.im_trash'), '删除当前模型', () => { this.modal = 'deleteModel'; })
          } else if (this.modal === 'convert') {
            Text('转换包会保留原始模型、因子表和规则，方便在不同建模工具之间交换。')
              .fontSize(12).fontColor('#929AAB').lineHeight(21).width('100%')
            this.action($r('app.media.im_export'), '导出原始模型 JSON', () => { this.modal = ''; this.exportModel(); })
            this.action($r('app.media.im_target'), '导出转换包 JSON', () => { this.modal = ''; this.exportConversion(); })
          } else {
            Text(this.modal === 'deleteModel' ? '删除模型「' + this.model().name + '」？' : '删除概念「' + this.selected().name + '」及其所有子概念？')
              .fontSize(14).fontColor('#6A768D').lineHeight(24).width('100%')
            Text('操作后可以通过撤销恢复。').fontSize(12).fontColor('#A1A8B8').width('100%')
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(25)
      }.width('100%').constraintSize({ maxHeight: 440 }).scrollBar(BarState.Auto)
      Row({ space: 10 }) {
        Blank()
        this.action($r('app.media.im_close'), this.modal === 'help' || this.modal === 'infer' || this.modal === 'modelOptions' || this.modal === 'convert' ? '关闭' : '取消', () => { this.modal = ''; })
        if (this.modal === 'new') { this.action($r('app.media.im_plus_white'), '创建模型', () => this.createModel(), true) }
        if (this.modal === 'deleteNode' || this.modal === 'deleteModel') {
          this.action($r('app.media.im_trash_white'), '确认删除', () => this.removeSelected(), true)
        }
      }.width('100%').padding({ left: 25, right: 25, top: 16, bottom: 20 })
    }.width(this.modal === 'infer' ? 560 : 460).borderRadius(14).backgroundColor('#FFFFFF')
      .shadow({ radius: 35, color: '#203C335D', offsetY: 10 })
  }
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.header()
        Row() {
          if (this.sidebarVisible) { this.sidebar() }
          Column() {
            if (this.models.length > 0) {
              this.heading()
              Row() {
                this.viewTab('tree', '分类树', $r('app.media.im_tree'))
                this.viewTab('decision', '决策树', $r('app.media.im_target'))
                this.viewTab('table', '因子表', $r('app.media.im_grid'))
                this.viewTab('rules', '规则', $r('app.media.im_rules'))
                Blank()
                Text(this.rows.length + ' 个概念').fontSize(10).fontColor('#A0A7B7').margin({ right: 24 })
              }.width('100%').padding({ left: 13 }).backgroundColor('#FFFFFF')
                .border({ width: { bottom: 1 }, color: '#E8E9F0' })
              this.editingToolbar()
              if (this.view === 'tree') { this.graph() }
              else if (this.view === 'decision') { this.decisionView() }
              else if (this.view === 'table') { this.factorTable() }
              else { this.rulesView() }
            } else {
              Column({ space: 18 }) {
                Image($r('app.media.im_logo')).width(54).height(54)
                Text('从一个概念开始').fontSize(24).fontWeight(600).fontColor('#626B80')
                Text('创建模型，连接知识，探索分类规则').fontSize(13).fontColor('#A2A9B9')
                this.action($r('app.media.im_plus_white'), '创建第一个模型', () => { this.modelName = ''; this.modal = 'new'; }, true)
              }.width('100%').height('100%').justifyContent(FlexAlign.Center)
            }
          }.layoutWeight(1).height('100%')
          if (this.inspectorVisible && this.models.length > 0) { this.inspector() }
        }.layoutWeight(1).width('100%').alignItems(VerticalAlign.Top)
        Row({ space: 7 }) {
          Row().width(5).height(5).backgroundColor('#66AA97').borderRadius(3)
          Text(this.savedStatus).fontSize(10).fontColor('#8A93A6')
          Blank()
          Text('HarmonyOS PC').fontSize(10).fontColor('#9DA5B5')
          Text('·').fontSize(10).fontColor('#CAD0DD')
          Text('InterModeller 1.1').fontSize(10).fontColor('#9DA5B5')
        }.height(29).width('100%').padding({ left: 20, right: 22 }).backgroundColor('#FFFFFF')
          .border({ width: { top: 1 }, color: '#E9EBF2' })
      }.width('100%').height('100%').backgroundColor('#FAFBFE')
      if (this.modal !== '') {
        Stack({ alignContent: Alignment.Center }) { this.dialog() }
          .width('100%').height('100%').backgroundColor('#55272E44')
      }
    }.width('100%').height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => {
        const width: number = Number(newArea.width);
        if (width < 1120 && this.rootWidth >= 1120) this.inspectorVisible = false;
        if (width >= 1120 && this.rootWidth < 1120) this.inspectorVisible = true;
        if (width < 780 && this.rootWidth >= 780) this.sidebarVisible = false;
        this.rootWidth = width;
      })
  }
}
