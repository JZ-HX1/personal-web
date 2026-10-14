import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ModelEngine } from '../model/ModelEngine';

interface BridgeResult {
  success: boolean;
  content?: string;
  message?: string;
  cancelled?: boolean;
  recovered?: boolean;
}

// Native ArkUI model storage and document import/export. All paths are
// application-owned or returned by the system document picker.
export class ModelBridge {
  private context?: common.UIAbilityContext;
  private readonly maxBytes: number = 4 * 1024 * 1024;

  initialize(context: common.UIAbilityContext): void {
    this.context = context;
  }

  private result(success: boolean, content: string = '', message: string = '', cancelled: boolean = false,
    recovered: boolean = false): string {
    const result: BridgeResult = { success: success, content: content, message: message, cancelled: cancelled,
      recovered: recovered };
    return JSON.stringify(result);
  }

  private message(error: Error, fallback: string): string {
    return error.message ? fallback + '：' + error.message : fallback;
  }

  private encode(content: string): Uint8Array {
    const bytes: Uint8Array = content.length === 0 ? new Uint8Array(0) :
      util.TextEncoder.create('utf-8').encodeInto(content);
    if (bytes.byteLength > this.maxBytes) throw new Error('内容不能超过 4 MB（按 UTF-8 字节计算）');
    return bytes;
  }

  // Read to EOF rather than relying on one read or the size reported by a document provider.
  // The extra byte detects a file that grows after stat, or a provider with an inaccurate size.
  private readDocument(path: string): string {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      if (fileIo.statSync(file.fd).size > this.maxBytes) throw new Error('文件不能超过 4 MB');
      const bytes: Uint8Array = new Uint8Array(this.maxBytes + 1);
      let total: number = 0;
      while (total <= this.maxBytes) {
        const chunk: ArrayBuffer = new ArrayBuffer(Math.min(65536, this.maxBytes + 1 - total));
        const length: number = fileIo.readSync(file.fd, chunk);
        if (length === 0) break;
        if (length < 0 || length > chunk.byteLength) throw new Error('文件读取长度异常');
        total += length;
        if (total > this.maxBytes) throw new Error('文件不能超过 4 MB');
        bytes.set(new Uint8Array(chunk, 0, length), total - length);
      }
      if (total === 0) return '';
      return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes.subarray(0, total));
    } finally {
      fileIo.closeSync(file);
    }
  }

  private readModels(path: string): string {
    const content: string = this.readDocument(path);
    ModelEngine.parseModels(content);
    return content;
  }

  private writeAll(file: fileIo.File, bytes: Uint8Array): void {
    let total: number = 0;
    while (total < bytes.byteLength) {
      const chunk: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset + total,
        bytes.byteOffset + Math.min(total + 65536, bytes.byteLength));
      const written: number = fileIo.writeSync(file.fd, chunk);
      if (written <= 0 || written > chunk.byteLength) throw new Error('文件未完整写入');
      total += written;
    }
    fileIo.fsyncSync(file.fd);
  }

  private writeLocal(path: string, bytes: Uint8Array): void {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE |
      fileIo.OpenMode.TRUNC);
    try {
      this.writeAll(file, bytes);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private removeTemporary(path: string): void {
    try {
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
    } catch (error) {
      // Cleanup is best effort; temporary files are never treated as stored models.
    }
  }

  // Rename is atomic when supported by the provider. Some providers reject a
  // destination that already exists, so remove it only after a complete temp
  // file is ready and restore the old bytes if the replacement still fails.
  private replacePath(temp: string, destination: string, restore: string): void {
    try {
      fileIo.renameSync(temp, destination);
      return;
    } catch (error) {
      // Retry below after removing an existing destination.
    }
    if (fileIo.accessSync(destination)) fileIo.unlinkSync(destination);
    try {
      fileIo.renameSync(temp, destination);
    } catch (error) {
      if (restore.length > 0) {
        try {
          this.writeLocal(destination, this.encode(restore));
        } catch (restoreError) {
          // The original error remains the actionable result.
        }
      }
      throw new Error(error instanceof Error ? error.message : '文件替换失败');
    }
  }

  loadModels(): string {
    if (!this.context) return this.result(false, '', '应用上下文尚未就绪');
    const path: string = this.context.filesDir + '/intermodeller-models.json';
    const backup: string = path + '.bak';
    let missing: boolean = false;
    try {
      missing = !fileIo.accessSync(path);
      if (!missing) return this.result(true, this.readModels(path));
    } catch (error) {
      // A corrupt or unreadable main file is kept untouched for recovery or inspection.
    }
    try {
      if (fileIo.accessSync(backup)) {
        const content: string = this.readModels(backup);
        return this.result(true, content, '已从最近一次有效备份恢复；原文件已保留', false, true);
      }
      if (missing) return this.result(true, 'null');
    } catch (error) {
      return this.result(false, '', this.message(error as Error, '本地模型及备份无法读取，原文件已保留'));
    }
    return this.result(false, '', '读取本地模型失败，未找到有效备份；原文件已保留');
  }

  saveModels(content: string): string {
    if (!this.context) return this.result(false, '', '应用上下文尚未就绪');
    const path: string = this.context.filesDir + '/intermodeller-models.json';
    const temp: string = path + '.tmp';
    const backup: string = path + '.bak';
    const backupTemp: string = backup + '.tmp';
    try {
      const bytes: Uint8Array = this.encode(content);
      ModelEngine.parseModels(content);
      this.writeLocal(temp, bytes);
      // Keep the previous valid version. Never rotate corrupt data into a good backup.
      let previous: string = '';
      let originalMain: string = '';
      try {
        if (fileIo.accessSync(path)) {
          originalMain = this.readDocument(path);
          ModelEngine.parseModels(originalMain);
          previous = originalMain;
        }
      } catch (error) {
        // If the main file is damaged, retain an existing valid backup instead.
      }
      let hasBackup: boolean = false;
      let previousBackup: string = '';
      if (!previous) {
        try {
          if (fileIo.accessSync(backup)) {
            previousBackup = this.readModels(backup);
            hasBackup = true;
          }
        } catch (error) {
          // An invalid backup can be replaced by the newly validated model data.
        }
      }
      if (previous || !hasBackup) {
        this.writeLocal(backupTemp, previous ? this.encode(previous) : bytes);
        this.replacePath(backupTemp, backup, previousBackup);
      }
      this.replacePath(temp, path, originalMain);
      return this.result(true);
    } catch (error) {
      return this.result(false, '', this.message(error as Error, '保存失败，原文件已保留'));
    } finally {
      this.removeTemporary(temp);
      this.removeTemporary(backupTemp);
    }
  }

  async importFile(): Promise<string> {
    if (!this.context) return this.result(false, '', '应用上下文尚未就绪');
    try {
      const view: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await view.select({ maxSelectNumber: 1, fileSuffixFilters: ['模型文件|.json'] });
      if (uris.length === 0) return this.result(false, '', '已取消导入', true);
      return this.result(true, this.readModels(uris[0]));
    } catch (error) {
      return this.result(false, '', this.message(error as Error, '未能导入所选模型文件'));
    }
  }

  async exportFile(content: string, suggestedName: string, extension: string): Promise<string> {
    if (!this.context) return this.result(false, '', '应用上下文尚未就绪');
    if (extension !== 'json' && extension !== 'svg' && extension !== 'csv' && extension !== 'txt') {
      return this.result(false, '', '不支持的文件格式');
    }
    try {
      const bytes: Uint8Array = this.encode(content);
      const name: string = suggestedName.replace(/[\\/:*?"<>|]/g, '_').slice(0, 80) + '.' + extension;
      const view: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const uris: string[] = await view.save({ newFileNames: [name], fileSuffixChoices: ['.' + extension] });
      if (uris.length === 0) return this.result(false, '', '已取消导出', true);
      const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        this.writeAll(file, bytes);
      } finally {
        fileIo.closeSync(file);
      }
      return this.result(true);
    } catch (error) {
      return this.result(false, '', this.message(error as Error, '未能保存导出文件'));
    }
  }
}
