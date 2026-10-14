import { ConceptModel } from './ModelEngine';

export const SAMPLE_MODELS: ConceptModel[] = [
  {
    "id": "demo-animal",
    "name": "动物分类",
    "description": "脊椎动物分类模型",
    "createdAt": 1791966936230,
    "root": {
      "id": "demo-node-1",
      "name": "动物",
      "description": "",
      "attributes": [],
      "collapsed": false,
      "children": [
        {
          "id": "demo-node-2",
          "name": "哺乳动物",
          "description": "温血、胎生",
          "attributes": [
            "温血",
            "胎生",
            "哺乳"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-3",
              "name": "猫科",
              "description": "",
              "attributes": [
                "可伸缩爪"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-4",
                  "name": "猫",
                  "description": "家猫",
                  "attributes": [
                    "小型",
                    "宠物"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-5",
                  "name": "狮",
                  "description": "草原之王",
                  "attributes": [
                    "大型",
                    "野生"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            },
            {
              "id": "demo-node-6",
              "name": "犬科",
              "description": "",
              "attributes": [
                "群居"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-7",
                  "name": "狼",
                  "description": "",
                  "attributes": [
                    "野生"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-8",
                  "name": "狗",
                  "description": "人类朋友",
                  "attributes": [
                    "宠物"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            }
          ]
        },
        {
          "id": "demo-node-9",
          "name": "鸟类",
          "description": "有羽毛、卵生",
          "attributes": [
            "有羽毛",
            "卵生",
            "温血"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-10",
              "name": "鹰",
              "description": "猛禽",
              "attributes": [
                "猛禽",
                "大型"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-11",
              "name": "麻雀",
              "description": "常见小鸟",
              "attributes": [
                "小型"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        },
        {
          "id": "demo-node-12",
          "name": "爬行动物",
          "description": "冷血、有鳞",
          "attributes": [
            "冷血",
            "有鳞",
            "卵生"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-13",
              "name": "蛇",
              "description": "",
              "attributes": [
                "无足"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-14",
              "name": "龟",
              "description": "",
              "attributes": [
                "有壳"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        }
      ]
    }
  },
  {
    "id": "demo-vehicle",
    "name": "交通工具",
    "description": "交通工具分类",
    "createdAt": 1791966936230,
    "root": {
      "id": "demo-node-15",
      "name": "交通工具",
      "description": "",
      "attributes": [],
      "collapsed": false,
      "children": [
        {
          "id": "demo-node-16",
          "name": "陆地",
          "description": "",
          "attributes": [
            "陆地行驶"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-17",
              "name": "汽车",
              "description": "",
              "attributes": [
                "四轮",
                "内燃"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-18",
              "name": "自行车",
              "description": "",
              "attributes": [
                "两轮",
                "人力"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-19",
              "name": "火车",
              "description": "",
              "attributes": [
                "轨道",
                "多节"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        },
        {
          "id": "demo-node-20",
          "name": "水上",
          "description": "",
          "attributes": [
            "水面航行"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-21",
              "name": "轮船",
              "description": "",
              "attributes": [
                "大型",
                "机动"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-22",
              "name": "帆船",
              "description": "",
              "attributes": [
                "风力"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        },
        {
          "id": "demo-node-23",
          "name": "空中",
          "description": "",
          "attributes": [
            "空中飞行"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-24",
              "name": "飞机",
              "description": "",
              "attributes": [
                "固定翼",
                "大型"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-25",
              "name": "直升机",
              "description": "",
              "attributes": [
                "旋翼"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        }
      ]
    }
  },
  {
    "id": "demo-plant",
    "name": "植物分类",
    "description": "主要植物类群",
    "createdAt": 1791966936230,
    "root": {
      "id": "demo-node-26",
      "name": "植物",
      "description": "",
      "attributes": [],
      "collapsed": false,
      "children": [
        {
          "id": "demo-node-27",
          "name": "被子植物",
          "description": "开花结果",
          "attributes": [
            "开花",
            "有果实"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-28",
              "name": "单子叶",
              "description": "",
              "attributes": [
                "平行脉"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-29",
                  "name": "水稻",
                  "description": "",
                  "attributes": [
                    "粮食"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-30",
                  "name": "玉米",
                  "description": "",
                  "attributes": [
                    "粮食"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            },
            {
              "id": "demo-node-31",
              "name": "双子叶",
              "description": "",
              "attributes": [
                "网状脉"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-32",
                  "name": "玫瑰",
                  "description": "",
                  "attributes": [
                    "观赏"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-33",
                  "name": "大豆",
                  "description": "",
                  "attributes": [
                    "粮食"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            }
          ]
        },
        {
          "id": "demo-node-34",
          "name": "裸子植物",
          "description": "种子裸露",
          "attributes": [
            "无花",
            "无果实"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-35",
              "name": "松树",
              "description": "",
              "attributes": [
                "常绿"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-36",
              "name": "银杏",
              "description": "",
              "attributes": [
                "落叶"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        }
      ]
    }
  },
  {
    "id": "demo-shape",
    "name": "几何图形",
    "description": "基本几何图形分类",
    "createdAt": 1791966936230,
    "root": {
      "id": "demo-node-37",
      "name": "几何图形",
      "description": "",
      "attributes": [],
      "collapsed": false,
      "children": [
        {
          "id": "demo-node-38",
          "name": "多边形",
          "description": "由直线段组成",
          "attributes": [
            "直线段"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-39",
              "name": "三角形",
              "description": "三边",
              "attributes": [
                "3边"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-40",
                  "name": "等边三角形",
                  "description": "",
                  "attributes": [
                    "等边"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-41",
                  "name": "直角三角形",
                  "description": "",
                  "attributes": [
                    "直角"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            },
            {
              "id": "demo-node-42",
              "name": "四边形",
              "description": "四边",
              "attributes": [
                "4边"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-43",
                  "name": "正方形",
                  "description": "",
                  "attributes": [
                    "等边",
                    "直角"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-44",
                  "name": "矩形",
                  "description": "",
                  "attributes": [
                    "直角"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            }
          ]
        },
        {
          "id": "demo-node-45",
          "name": "圆",
          "description": "曲线",
          "attributes": [
            "曲线",
            "无限对称"
          ],
          "collapsed": false,
          "children": []
        }
      ]
    }
  },
  {
    "id": "demo-lang",
    "name": "编程语言",
    "description": "编程语言分类",
    "createdAt": 1791966936230,
    "root": {
      "id": "demo-node-46",
      "name": "编程语言",
      "description": "",
      "attributes": [],
      "collapsed": false,
      "children": [
        {
          "id": "demo-node-47",
          "name": "编译型",
          "description": "需要编译器",
          "attributes": [
            "编译执行"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-48",
              "name": "C",
              "description": "",
              "attributes": [
                "底层",
                "过程式"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-49",
              "name": "Java",
              "description": "",
              "attributes": [
                "面向对象",
                "跨平台"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-50",
              "name": "Go",
              "description": "",
              "attributes": [
                "并发",
                "简洁"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        },
        {
          "id": "demo-node-51",
          "name": "解释型",
          "description": "逐行解释执行",
          "attributes": [
            "解释执行"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-52",
              "name": "Python",
              "description": "",
              "attributes": [
                "动态",
                "简洁"
              ],
              "collapsed": false,
              "children": []
            },
            {
              "id": "demo-node-53",
              "name": "JavaScript",
              "description": "",
              "attributes": [
                "Web",
                "动态"
              ],
              "collapsed": false,
              "children": []
            }
          ]
        }
      ]
    }
  },
  {
    "id": "demo-file",
    "name": "文件格式",
    "description": "常见文件格式分类",
    "createdAt": 1791966936230,
    "root": {
      "id": "demo-node-54",
      "name": "文件格式",
      "description": "",
      "attributes": [],
      "collapsed": false,
      "children": [
        {
          "id": "demo-node-55",
          "name": "文本文件",
          "description": "",
          "attributes": [
            "可读"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-56",
              "name": "源代码",
              "description": "",
              "attributes": [
                "代码"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-57",
                  "name": ".js",
                  "description": "JavaScript",
                  "attributes": [
                    "脚本"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-58",
                  "name": ".py",
                  "description": "Python",
                  "attributes": [
                    "脚本"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            },
            {
              "id": "demo-node-59",
              "name": "配置文件",
              "description": "",
              "attributes": [
                "配置"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-60",
                  "name": ".json",
                  "description": "JSON",
                  "attributes": [
                    "结构化"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-61",
                  "name": ".xml",
                  "description": "XML",
                  "attributes": [
                    "标记语言"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            }
          ]
        },
        {
          "id": "demo-node-62",
          "name": "二进制文件",
          "description": "",
          "attributes": [
            "不可读"
          ],
          "collapsed": false,
          "children": [
            {
              "id": "demo-node-63",
              "name": "图片",
              "description": "",
              "attributes": [
                "视觉"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-64",
                  "name": ".png",
                  "description": "PNG",
                  "attributes": [
                    "无损"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-65",
                  "name": ".jpg",
                  "description": "JPEG",
                  "attributes": [
                    "有损"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            },
            {
              "id": "demo-node-66",
              "name": "可执行文件",
              "description": "",
              "attributes": [
                "可运行"
              ],
              "collapsed": false,
              "children": [
                {
                  "id": "demo-node-67",
                  "name": ".exe",
                  "description": "Windows",
                  "attributes": [
                    "PE"
                  ],
                  "collapsed": false,
                  "children": []
                },
                {
                  "id": "demo-node-68",
                  "name": ".so",
                  "description": "Linux",
                  "attributes": [
                    "共享库"
                  ],
                  "collapsed": false,
                  "children": []
                }
              ]
            }
          ]
        }
      ]
    }
  }
];
