/* ============================================================
 * 个人资料数据文件
 * 以后修改/添加项目，只需要编辑这个文件即可，不用动其他代码
 * ============================================================ */

// ---- 专业技能（会自动渲染到“技能”板块，百分比只是展示效果）----
const SKILLS = [
  {
    name: "Python 程序设计",
    level: 88,
    tags: ["NCRE 二级", "爬虫", "数据处理"],
  },
  {
    name: "C / C++",
    level: 78,
    tags: ["数据结构", "算法"],
  },
  {
    name: "Web 前端",
    level: 72,
    tags: ["HTML", "CSS", "JavaScript"],
  },
  {
    name: "数据库",
    level: 70,
    tags: ["MySQL", "SQLite"],
  },
  {
    name: "工具与环境",
    level: 75,
    tags: ["Git", "VS Code", "Linux"],
  },
  {
    name: "其他",
    level: 60,
    tags: ["Java", "持续学习中"],
  },
];

// ---- 项目列表 ----
// 每个项目字段说明：
//   title: 项目名称
//   desc:  项目简介（一两句话说明做了什么、用了什么技术）
//   icon:  项目封面图标（emoji，可自行更换）
//   tags:  技术标签
//   category: 分类（用于筛选，如 "课程设计" "Web开发" "小程序" 等）
//   year:  完成年份
//   links: 可选，{ text: "GitHub", url: "https://..." }，没有就写 null
const PROJECTS = [
  // ★★★ 以下为示例项目，请替换成你自己做过的所有项目 ★★★
  {
    title: "学生成绩管理系统",
    desc: "基于 Python + SQLite 的成绩管理系统，支持学生信息增删改查、成绩统计分析与导出报表。",
    icon: "🎓",
    tags: ["Python", "SQLite", "Tkinter"],
    category: "课程设计",
    year: "2025",
    links: { text: "GitHub", url: "https://github.com/yourname/student-system" },
  },
  {
    title: "个人博客网站",
    desc: "使用 HTML/CSS/JavaScript 搭建的响应式个人博客，支持文章列表、分类浏览与暗色模式。",
    icon: "📝",
    tags: ["HTML", "CSS", "JavaScript"],
    category: "Web开发",
    year: "2025",
    links: null,
  },
  {
    title: "天气数据爬虫与分析",
    desc: "爬取历史天气数据并进行清洗与可视化分析，生成气温变化趋势图表。",
    icon: "🌦️",
    tags: ["Python", "Requests", "Matplotlib"],
    category: "数据爬虫",
    year: "2026",
    links: null,
  },
  // ★★★ 在这里继续往下添加你的所有项目 ★★★
];

// ---- 项目分类（会自动生成筛选按钮）----
const PROJECT_CATEGORIES = ["全部", "课程设计", "Web开发", "数据爬虫"];
