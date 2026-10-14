# InterModeller · 鸿蒙 PC 原生应用

在 DevEco Studio 打开本目录 `E:\computerproject\pc`，入口模块为 `entry`。`ohos_intermodeller/` 是保留的上游参考仓库。

本项目参考上游 [OpenHarmonyPCDeveloper/ohos_intermodeller](https://atomgit.com/OpenHarmonyPCDeveloper/ohos_intermodeller)，当前仓库提交的是面向 HarmonyOS PC 的原生 ArkUI 工程。上游目录、缓存和构建产物不纳入本仓库；上游项目未随源文件提供许可证声明，使用或再发布上游内容时请遵守其项目页面和贡献者要求。

界面已使用 ArkTS / ArkUI 原生组件实现：模型库、大纲搜索、分类树画布、概念增删改、折叠展开、撤销重做、因子表、规则推导、决策树问答、特征匹配推理和模型转换导出。内置六个上游示例模型。应用不依赖 Electron、Web 组件或在线资源。

## 预览与运行

1. 打开 `entry/src/main/ets/pages/Index.ets`，刷新右侧 Previewer，使用 2in1 设备尺寸。
2. 预览器中可查看示例和操作界面；系统文件选择与持久化需要模拟器或真机环境。
3. 在 DevEco Device Manager 启动鸿蒙 PC 模拟器，或连接开启调试的设备。
4. 在 Project Structure 的 Signing Configs 中配置本机调试签名，选择设备后运行 `entry`。

JSON 导出采用上游兼容的模型数组结构。导入会追加模型，不会替换现有工作空间。文件通过系统文档选择器读写，模型自动保存在应用沙箱，未选中的推理特征视为未知。

## 本机构建与测试

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Preview
node scripts/test-model.cjs
```

构建脚本默认使用本机 `D:\Program Files\DevEco Studio`，可通过 `-DevEcoHome` 参数指定其他目录。

未签名产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。未签名包不能直接作为已签名设备安装包使用。

纯数据层测试覆盖六个样例、不可变节点增删改、子树删除、折叠布局、规则条件继承、JSON 校验以及数量和深度限制。Node 测试不代替 ArkTS 编译或设备 UI 测试。

## 已执行验证

原生 assembleHap 与 PreviewBuild 成功；14 项模型与决策引擎测试通过。已在本机连接的鸿蒙 PC 模拟器（127.0.0.1:5555）安装并启动，检查了分类树、因子表、节点属性、规则视图和决策树问答，并实际通过特征匹配到“猫”的规则。真机安装仍需配置本机签名。
