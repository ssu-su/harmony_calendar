  // 公历转农历算法
interface LunarDateResult {
  lunarYear: number;
  lunarMonth: number;
  lunarDay: number;
  isLeap: boolean;
}

interface CalendarEvent {
  id: string;
  title: string;
  description?: string;
  startTime: Date;
  endTime: Date;
  allDay: boolean;
  source?: string; // local / imported / subscription
  reminderMinutes?: number; // 提前多少分钟提醒，0表示不提醒
  reminded?: boolean; // 是否已经提醒过
}

interface SubscriptionSource {
  id: string;
  name: string;
  url: string;
  lastSync?: Date;
}

@Entry
@Component
struct Index {
  @State currentDate: Date = new Date();
  @State currentView: string = 'month'; // 'month' | 'week' | 'day'
  @State events: CalendarEvent[] = [];
  @State showEditor: boolean = false;
  @State editingTitle: string = '';
  @State editingDescription: string = '';
  @State editingAllDay: boolean = false;
  @State editingStartHour: number = 9;
  @State editingEndHour: number = 10;
  @State editingStartMinute: number = 0;
  @State editingEndMinute: number = 0;
  @State editorError: string = '';
  @State showExportDialog: boolean = false;
  @State exportedIcs: string = '';
  @State showImportDialog: boolean = false;
  @State icsImportText: string = '';
  @State showTopMenu: boolean = false;
  @State showJumpDialog: boolean = false;
  @State jumpYear: number = 2025;
  @State jumpMonth: number = 1;
  @State jumpDay: number = 1;
  @State editingEventId: string = ''; // 空字符串表示新增，非空表示编辑
  @State editingReminderMinutes: number = 0; // 提醒时间（分钟）
  @State showSubscriptionDialog: boolean = false;
  @State subscriptionUrl: string = '';
  @State subscriptionName: string = '';
  @State subscriptions: SubscriptionSource[] = [];
  @State reminderCheckInterval: number = 0;

  private weekDays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
  private monthRows: number[] = [0, 1, 2, 3, 4, 5];
  private monthCols: number[] = [0, 1, 2, 3, 4, 5, 6];
  private weekIndices: number[] = [0, 1, 2, 3, 4, 5, 6];

  aboutToAppear() {
    this.startReminderCheck();
  }

  aboutToDisappear() {
    // 清理定时器
    if (this.reminderCheckInterval !== 0) {
      clearInterval(this.reminderCheckInterval);
    }
  }

  private startReminderCheck(): void {
    this.reminderCheckInterval = setInterval(() => {
      this.checkReminders();
    }, 10000); // 每10秒检查
    // 立即检查一次
    this.checkReminders();
  }

  @State reminderMessage: string = '';
  @State showReminderAlert: boolean = false;

  private checkReminders() {
    // 获取当前设备时间（如果是模拟器运行，则为模拟器时间）
    const now: Date = new Date();
    const nowTime: number = now.getTime();

    for (let i: number = 0; i < this.events.length; i++) {
      const event: CalendarEvent = this.events[i];
      if (event.reminded || !event.reminderMinutes || event.reminderMinutes <= 0) {
        continue;
      }

      const eventTime: number = event.startTime.getTime();
      const reminderTime: number = eventTime - event.reminderMinutes * 60 * 1000;

      // 如果当前时间在提醒时间之后，且在事件开始时间之前
      if (nowTime >= reminderTime && nowTime < eventTime) {
        // 触发提醒
        this.reminderMessage = `【${event.title}】将在${event.reminderMinutes}分钟后开始`;
        this.showReminderAlert = true;

        // 标记为已提醒
        const index = this.events.findIndex(e => e.id === event.id);
        if (index !== -1) {
          const original = this.events[index];
          const updated: CalendarEvent = {
            id: original.id,
            title: original.title,
            description: original.description,
            startTime: original.startTime,
            endTime: original.endTime,
            allDay: original.allDay,
            source: original.source,
            reminderMinutes: original.reminderMinutes,
            reminded: true
          };
          // 使用新数组强制刷新状态
          const newEvents = [...this.events];
          newEvents[index] = updated;
          this.events = newEvents;
        }
        break;
      }
    }
  }

  build() {
    Column() {
      // 顶部一行：左边今天按钮，中间左右切月 + 当前月份（2025.12），右边菜单
      Row() {
        // 今天（文字按钮）
        Text('今天')
          .fontSize(13)
          .fontColor('#2563EB')
          .padding({ right: 8 })
          .onClick(() => {
            this.currentDate = new Date();
          })

        Blank()

        // 中间：左右切月 + 当前月份
        Row() {
          Text('<')
            .fontSize(18)
            .fontColor('#4B5563')
            .padding({ left: 4, right: 8 })
            .onClick(() => {
              this.shiftMonth(-1);
            })

          Text(this.getHeaderSubtitle())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
            .margin({ left: 4, right: 4 })

          Text('>')
            .fontSize(18)
            .fontColor('#4B5563')
            .padding({ left: 8, right: 4 })
            .onClick(() => {
              this.shiftMonth(1);
            })
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Blank()

        // 顶部更多菜单（竖着的两个点图标）
        Text('⋮')
          .fontSize(18)
          .fontColor('#6B7280')
          .padding({ left: 12 })
          .onClick(() => {
            this.showTopMenu = true;
          })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })
      .backgroundColor(Color.White)

      // 视图切换 Tab（细长一行）
      Row() {
        this.renderTab('month', '月');
        this.renderTab('week', '周');
        this.renderTab('day', '日');
      }
      .margin({ top: 4, left: 16, right: 16, bottom: 4 })

      // 日历主体区域
      Column() {
        // 星期栏
        Row() {
          ForEach(this.weekDays, (day: string) => {
            Text(day)
              .fontSize(12)
              .fontColor('#9AA4B2')
              .textAlign(TextAlign.Center)
              .width('14.28%');
          }, (day: string) => day)
        }
        .margin({ top: 8, bottom: 8 })

        // 月视图网格骨架
        if (this.currentView === 'month') {
          Column() {
            ForEach(this.monthRows, (rowIndex: number) => {
              Row() {
                ForEach(this.monthCols, (colIndex: number) => {
                  Column() {
                    // 日期数字
                    Text(`${this.getMonthCellDate(rowIndex, colIndex).getDate()}`)
                      .fontSize(14)
                      .fontColor(
                        this.isCellInCurrentMonth(rowIndex, colIndex)
                          ? (this.isCellToday(rowIndex, colIndex)
                            ? Color.White
                            : (this.isSameDate(this.getMonthCellDate(rowIndex, colIndex), this.currentDate)
                              ? '#1D4ED8'
                              : '#111827'))
                          : '#D1D5DB')
                      .textAlign(TextAlign.Center)
                      .width('100%');

                    // 农历小字（简化版）
                    Text(this.getLunarLabel(this.getMonthCellDate(rowIndex, colIndex)))
                      .fontSize(9)
                      .fontColor(this.isCellToday(rowIndex, colIndex) ? '#E5E7EB' : '#9CA3AF')
                      .margin({ top: 1 })

                    // 事件小圆点（最多2个，纵向）
                    Column() {
                      ForEach(this.getEventDotArray(this.getMonthCellDate(rowIndex, colIndex)), (dotIndex: number) => {
                        Row()
                          .width(4)
                          .height(4)
                          .backgroundColor(this.isCellToday(rowIndex, colIndex) ? Color.White : '#3B82F6')
                          .borderRadius(2)
                          .margin({ top: dotIndex === 0 ? 1 : 2 })
                      }, (dotIndex: number) => `${rowIndex}-${colIndex}-dot-${dotIndex}`)
                    }
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)
                  }
                  .width('14.28%')
                  .height(52)
                  .borderRadius(12)
                  .backgroundColor(
                    this.isCellToday(rowIndex, colIndex) && this.isCellInCurrentMonth(rowIndex, colIndex)
                      ? '#4C6FFF'
                      : (this.isSameDate(this.getMonthCellDate(rowIndex, colIndex), this.currentDate)
                        && this.isCellInCurrentMonth(rowIndex, colIndex)
                        ? '#DBEAFE'
                        : 'transparent')
                  )
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .onClick(() => {
                    this.currentDate = this.getMonthCellDate(rowIndex, colIndex);
                  })
                }, (colIndex: number) => `${rowIndex}-${colIndex}`)
              }
              .margin({ top: 4, bottom: 4 })
            }, (rowIndex: number) => `${rowIndex}`)
          }
        }
      }
      .margin({ left: 16, right: 16, bottom: 8 })

      // 周视图和日视图（可滚动）
      if (this.currentView === 'week') {
        this.buildWeekView();
      } else if (this.currentView === 'day') {
        this.buildDayView();
      }

      // 月视图下方：选中日期的日程列表（可滚动）
      if (this.currentView === 'month') {
        Scroll() {
          Column() {
            if (this.getEventsForDate(this.currentDate).length === 0) {
              Text('这一天没有安排日程')
                .fontSize(13)
                .fontColor('#6B7280')
                .margin({ top: 16 })
            } else {
              ForEach(this.getEventsForDate(this.currentDate), (event: CalendarEvent) => {
                Row() {
                  // 左侧时间
                  Text(this.formatTimeRange(event))
                    .fontSize(13)
                    .fontColor('#6B7280')
                    .width(90)

                  // 右侧事件信息
                  Column() {
                    Text(event.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#111827')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                    if (event.description) {
                      Text(event.description)
                        .fontSize(12)
                        .fontColor('#6B7280')
                        .margin({ top: 2 })
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor(Color.White)
                .borderRadius(10)
                .margin({ bottom: 8 })
                .onClick(() => {
                  this.openEditEventEditor(event);
                })
              }, (event: CalendarEvent) => `month-${event.id}-${event.title}-${event.startTime.getTime()}`)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
      }

      // 浮动添加按钮
      Row() {
        Blank();
        Button('+')
          .type(ButtonType.Circle)
          .width(56)
          .height(56)
          .fontSize(28)
          .backgroundColor('#4C6FFF')
          .fontColor(Color.White)
          .shadow({
            radius: 20,
            color: 'rgba(76, 111, 255, 0.6)',
            offsetX: 0,
            offsetY: 10
          })
          .onClick(() => {
            this.openNewEventEditor();
          })
      }
      .margin({ right: 24, bottom: 36 })
      .alignItems(VerticalAlign.Bottom)

      // 简单事件编辑弹层
      if (this.showEditor) {
        Column() {
          Column() {
            Text(this.editingEventId !== '' ? '编辑日程' : '新增日程')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 12 })

            Scroll() {
              Column() {
                // 标题
                Text('标题')
                  .fontSize(13)
                  .fontColor('#6B7280')
                TextInput({ text: this.editingTitle, placeholder: '例如：和同学聚餐' })
                  .onChange((value: string) => {
                    this.editingTitle = value;
                  })
                  .margin({ bottom: 8 })

                // 描述
                Text('备注')
                  .fontSize(13)
                  .fontColor('#6B7280')
                TextInput({ text: this.editingDescription, placeholder: '可选，例如：地点、内容等' })
                  .onChange((value: string) => {
                    this.editingDescription = value;
                  })
                  .margin({ bottom: 8 })

                // 全天开关
                Row() {
                  Text('全天')
                    .fontSize(13)
                    .fontColor('#4B5563')
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: this.editingAllDay })
                    .onChange((value: boolean) => {
                      this.editingAllDay = value;
                    })
                }
                .margin({ top: 4, bottom: 8 })

                // 时间（使用时分滑动选择器）
                if (!this.editingAllDay) {
                  Column() {
                    Text('开始时间')
                      .fontSize(13)
                      .fontColor('#4B5563')
                      .margin({ bottom: 4 })

                    TimePicker({
                      selected: new Date(0, 0, 1, this.editingStartHour, this.editingStartMinute, 0)
                    })
                      .onChange((value) => {
                        this.editingStartHour = value.hour;
                        this.editingStartMinute = value.minute;
                      })

                    Blank().height(8)

                    Text('结束时间')
                      .fontSize(13)
                      .fontColor('#4B5563')
                      .margin({ bottom: 4 })

                    TimePicker({
                      selected: new Date(0, 0, 1, this.editingEndHour, this.editingEndMinute, 0)
                    })
                      .onChange((value) => {
                        this.editingEndHour = value.hour;
                        this.editingEndMinute = value.minute;
                      })
                  }
                }

                // 提醒设置
                Row() {
                  Text('提前提醒')
                    .fontSize(13)
                    .fontColor('#4B5563')
                  Blank()
                  Select([
                    { value: '不提醒' },
                    { value: '5分钟' },
                    { value: '15分钟' },
                    { value: '30分钟' },
                    { value: '1小时' }
                  ])
                    .selected(this.getReminderSelectIndex())
                    .value(this.getReminderSelectValue())
                    .onSelect((index: number) => {
                      const values: number[] = [0, 5, 15, 30, 60];
                      this.editingReminderMinutes = values[index];
                    })
                }
                .margin({ top: 8, bottom: 8 })

                // 校验错误提示
                if (this.editorError && this.editorError !== '') {
                  Text(this.editorError)
                    .fontSize(12)
                    .fontColor('#DC2626')
                    .margin({ top: 6 })
                }
              }
            }
            .height('50vh')
            .scrollBar(BarState.Auto)

            // 按钮行
            Row() {
              if (this.editingEventId !== '') {
                Button('删除')
                  .backgroundColor('#FEE2E2')
                  .fontColor('#DC2626')
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.deleteEvent(this.editingEventId);
                    this.showEditor = false;
                  })
              }

              Button('取消')
                .backgroundColor('#E5E7EB')
                .fontColor('#374151')
                .margin({ right: 8 })
                .onClick(() => {
                  this.showEditor = false;
                })

              Button('保存')
                .backgroundColor('#2563EB')
                .fontColor(Color.White)
                .onClick(() => {
                  this.saveNewEvent();
                })
            }
            .margin({ top: 16, bottom: 8 })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding({ left: 20, right: 20, top: 28, bottom: 28 })
          .width('90%')
          .constraintSize({ maxHeight: '80%' })
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showEditor = false;
        })
        .position({ x: 0, y: 0 })
      }

      // 顶部更多菜单弹层
      if (this.showTopMenu) {
        Column() {
          Column() {
            Text('菜单')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 12 })

            Row() {
              Text('📅')
                .fontSize(16)
                .margin({ right: 12 })
              Text('跳转到日期')
                .fontSize(14)
                .fontColor('#374151')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showTopMenu = false;
              this.showJumpDialog = true;
            })

            Divider().color('#E5E7EB')

            Row() {
              Text('🏠')
                .fontSize(16)
                .margin({ right: 12 })
              Text('回到今天')
                .fontSize(14)
                .fontColor('#374151')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.currentDate = new Date();
              this.showTopMenu = false;
            })

            Divider().color('#E5E7EB')

            Row() {
              Text('📤')
                .fontSize(16)
                .margin({ right: 12 })
              Text('导出日程')
                .fontSize(14)
                .fontColor('#374151')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.exportedIcs = this.exportEventsToIcs();
              this.showTopMenu = false;
              this.showExportDialog = true;
            })

            Divider().color('#E5E7EB')

            Row() {
              Text('📥')
                .fontSize(16)
                .margin({ right: 12 })
              Text('导入日程')
                .fontSize(14)
                .fontColor('#374151')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.icsImportText = '';
              this.showTopMenu = false;
              this.showImportDialog = true;
            })

            Divider().color('#E5E7EB')

            Row() {
              Text('🌐')
                .fontSize(16)
                .margin({ right: 12 })
              Text('网络订阅')
                .fontSize(14)
                .fontColor('#374151')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              this.subscriptionUrl = '';
              this.subscriptionName = '';
              this.showTopMenu = false;
              this.showSubscriptionDialog = true;
            })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })
          .width('80%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showTopMenu = false;
        })
        .position({ x: 0, y: 0 })
      }

      // 跳转日期弹层
      if (this.showJumpDialog) {
        Column() {
          Column() {
            Text('跳转到指定日期')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 16 })

            DatePicker({
              start: new Date('1970-1-1'),
              end: new Date('2100-12-31'),
              selected: this.currentDate
            })
              .onDateChange((value: Date) => {
                this.jumpYear = value.getFullYear();
                this.jumpMonth = value.getMonth() + 1;
                this.jumpDay = value.getDate();
              })

            Row() {
              Button('取消')
                .backgroundColor('#E5E7EB')
                .fontColor('#374151')
                .margin({ right: 8 })
                .onClick(() => {
                  this.showJumpDialog = false;
                })

              Button('跳转')
                .backgroundColor('#2563EB')
                .fontColor(Color.White)
                .onClick(() => {
                  this.currentDate = new Date(this.jumpYear, this.jumpMonth - 1, this.jumpDay);
                  this.showJumpDialog = false;
                })
            }
            .margin({ top: 16 })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })
          .width('85%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showJumpDialog = false;
        })
        .position({ x: 0, y: 0 })
      }

      // 导出弹层
      if (this.showExportDialog) {
        Column() {
          Column() {
            Text('导出日程 (ICS格式)')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 12 })

            Text('长按下方文本框可全选复制，然后保存为 .ics 文件')
              .fontSize(13)
              .fontColor('#6B7280')
              .margin({ bottom: 8 })

            TextArea({ text: this.exportedIcs })
              .fontSize(11)
              .fontColor('#374151')
              .backgroundColor('#F3F4F6')
              .padding(8)
              .borderRadius(4)
              .height(200)
              .width('100%')

            Button('关闭')
              .backgroundColor('#2563EB')
              .fontColor(Color.White)
              .margin({ top: 16 })
              .onClick(() => {
                this.showExportDialog = false;
              })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })
          .width('85%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showExportDialog = false;
        })
        .position({ x: 0, y: 0 })
      }

      // 导入弹层
      if (this.showImportDialog) {
        Column() {
          Column() {
            Text('导入日程 (ICS格式)')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 12 })

            Text('粘贴ICS内容，或点击“填充示例”测试：')
              .fontSize(13)
              .fontColor('#6B7280')
              .margin({ bottom: 8 })

            TextArea({ text: this.icsImportText, placeholder: 'BEGIN:VCALENDAR\nVERSION:2.0\n...' })
              .height(150)
              .onChange((value: string) => {
                this.icsImportText = value;
              })

            Row() {
              Button('填充示例')
                .backgroundColor('#F3F4F6')
                .fontColor('#374151')
                .margin({ right: 8 })
                .onClick(() => {
                  this.icsImportText = 'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:import-test-001\nSUMMARY:导入测试事件\nDESCRIPTION:这是一个导入的测试日程\nDTSTART:20251216T140000\nDTEND:20251216T150000\nEND:VEVENT\nEND:VCALENDAR';
                })

              Button('取消')
                .backgroundColor('#E5E7EB')
                .fontColor('#374151')
                .margin({ right: 8 })
                .onClick(() => {
                  this.showImportDialog = false;
                })

              Button('导入')
                .backgroundColor('#2563EB')
                .fontColor(Color.White)
                .onClick(() => {
                  const beforeCount: number = this.events.length;
                  this.importEventsFromIcs(this.icsImportText);
                  const afterCount: number = this.events.length;
                  const importedCount: number = afterCount - beforeCount;
                  if (importedCount > 0) {
                    this.reminderMessage = `成功导入 ${importedCount} 个日程`;
                    this.showReminderAlert = true;
                  }
                  this.showImportDialog = false;
                })
            }
            .margin({ top: 16 })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })
          .width('85%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showImportDialog = false;
        })
        .position({ x: 0, y: 0 })
      }

      // 网络订阅弹层
      if (this.showSubscriptionDialog) {
        Column() {
          Column() {
            Text('网络订阅')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 12 })

            Text('订阅名称')
              .fontSize(13)
              .fontColor('#6B7280')
            TextInput({ text: this.subscriptionName, placeholder: '例如：节假日日历' })
              .onChange((value: string) => {
                this.subscriptionName = value;
              })
              .margin({ bottom: 8 })

            Text('订阅地址 (ICS URL)')
              .fontSize(13)
              .fontColor('#6B7280')
            TextInput({ text: this.subscriptionUrl, placeholder: 'https://example.com/calendar.ics' })
              .onChange((value: string) => {
                this.subscriptionUrl = value;
              })
              .margin({ bottom: 8 })

            // 已有订阅列表
            if (this.subscriptions.length > 0) {
              Text('已订阅列表：')
                .fontSize(13)
                .fontColor('#6B7280')
                .margin({ top: 8, bottom: 4 })

              ForEach(this.subscriptions, (sub: SubscriptionSource) => {
                Row() {
                  Text(sub.name)
                    .fontSize(13)
                    .fontColor('#111827')
                    .layoutWeight(1)

                  Text('删除')
                    .fontSize(12)
                    .fontColor('#DC2626')
                    .onClick(() => {
                      this.removeSubscription(sub.id);
                    })
                }
                .padding({ top: 4, bottom: 4 })
              }, (sub: SubscriptionSource) => sub.id)
            }

            Row() {
              Button('取消')
                .backgroundColor('#E5E7EB')
                .fontColor('#374151')
                .margin({ right: 8 })
                .onClick(() => {
                  this.showSubscriptionDialog = false;
                })

              Button('添加订阅')
                .backgroundColor('#7C3AED')
                .fontColor(Color.White)
                .onClick(() => {
                  this.addSubscription();
                })
            }
            .margin({ top: 16 })
          }
          .backgroundColor(Color.White)
          .borderRadius(16)
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })
          .width('85%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showSubscriptionDialog = false;
        })
        .position({ x: 0, y: 0 })
      }

      // 提醒弹窗
      if (this.showReminderAlert) {
        Column() {
          Column() {
            // 图标（仅日程提醒显示）
            if (this.reminderMessage.includes('将在')) {
              Text('⏰')
                .fontSize(48)
                .margin({ bottom: 12 })
            }

            Text(this.reminderMessage.includes('将在') ? '日程提醒' : '提示')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')
              .margin({ bottom: 8 })

            Text(this.reminderMessage)
              .fontSize(16)
              .fontColor('#374151')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 24 })

            Button('我知道了')
              .width('100%')
              .height(44)
              .backgroundColor('#2563EB')
              .fontColor(Color.White)
              .fontSize(16)
              .onClick(() => {
                this.showReminderAlert = false;
              })
          }
          .backgroundColor(Color.White)
          .borderRadius(20)
          .padding({ left: 32, right: 32, top: 32, bottom: 24 })
          .width('80%')
          .alignItems(HorizontalAlign.Center)
        }
        .height('100%')
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showReminderAlert = false;
        })
        .position({ x: 0, y: 0 })
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F3F4F6')
  }

  @Builder
  private renderTab(key: string, label: string) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontWeight(this.currentView === key ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentView === key ? '#111827' : '#6B7280')
        .padding({ bottom: 4 })

      if (this.currentView === key) {
        Row()
          .width('60%')
          .height(3)
          .backgroundColor('#4C6FFF')
          .borderRadius(2);
      }
    }
    .width('33.33%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentView = key;
    })
  }

  private getHeaderSubtitle(): string {
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth() + 1;
    return `${year}.${month}`;
  }

  private shiftMonth(offset: number) {
    const d = new Date(this.currentDate.getTime());
    d.setMonth(d.getMonth() + offset);
    this.currentDate = d;
  }

  private openNewEventEditor() {
    this.editingEventId = '';
    this.editingTitle = '';
    this.editingDescription = '';
    this.editingAllDay = false;
    this.editingStartHour = 9;
    this.editingEndHour = 10;
    this.editingStartMinute = 0;
    this.editingEndMinute = 0;
    this.editingReminderMinutes = 15;
    this.editorError = '';
    this.showEditor = true;
  }

  private openEditEventEditor(event: CalendarEvent) {
    this.editingEventId = event.id;
    this.editingTitle = event.title;
    this.editingDescription = event.description || '';
    this.editingAllDay = event.allDay;
    this.editingStartHour = event.startTime.getHours();
    this.editingStartMinute = event.startTime.getMinutes();
    this.editingEndHour = event.endTime.getHours();
    this.editingEndMinute = event.endTime.getMinutes();
    this.editingReminderMinutes = event.reminderMinutes || 0;
    this.editorError = '';
    this.showEditor = true;
  }

  private saveNewEvent() {
    this.editorError = '';

    // 标题必填校验
    if (!this.editingTitle || this.editingTitle.trim() === '') {
      this.editorError = '请填写日程标题';
      return;
    }

    let base: Date = this.currentDate;
    // 如果是编辑模式，使用原事件的日期，确保修改时间时不会改变日期
    if (this.editingEventId !== '') {
      const originalEvent = this.events.find(e => e.id === this.editingEventId);
      if (originalEvent) {
        base = originalEvent.startTime;
      }
    }

    let startTime: Date;
    let endTime: Date;
    if (this.editingAllDay) {
      startTime = new Date(base.getFullYear(), base.getMonth(), base.getDate(), 0, 0);
      endTime = new Date(base.getFullYear(), base.getMonth(), base.getDate(), 23, 59);
    } else {
      const sh: number = this.editingStartHour;
      const sm: number = this.editingStartMinute;
      const eh: number = this.editingEndHour;
      const em: number = this.editingEndMinute;

      // 结束时间不能早于或等于开始时间
      const startTotal: number = sh * 60 + sm;
      const endTotal: number = eh * 60 + em;
      
      if (endTotal <= startTotal) {
        this.editorError = '结束时间必须晚于开始时间';
        return;
      }

      startTime = new Date(base.getFullYear(), base.getMonth(), base.getDate(), sh, sm);
      endTime = new Date(base.getFullYear(), base.getMonth(), base.getDate(), eh, em);
    }

    if (this.editingEventId !== '') {
      // 编辑模式：更新现有事件
      const index = this.events.findIndex(e => e.id === this.editingEventId);
      if (index !== -1) {
        const original = this.events[index];
        const updated: CalendarEvent = {
          id: original.id,
          title: this.editingTitle,
          description: this.editingDescription,
          startTime: startTime,
          endTime: endTime,
          allDay: this.editingAllDay,
          source: original.source,
          reminderMinutes: this.editingReminderMinutes,
          reminded: false
        };
        
        // 创建新数组以触发状态更新
        const newEvents = [...this.events];
        newEvents[index] = updated;
        this.events = newEvents;
      }
    } else {
      // 新增模式
      const newEvent: CalendarEvent = {
        id: `${Date.now()}`,
        title: this.editingTitle,
        description: this.editingDescription,
        startTime: startTime,
        endTime: endTime,
        allDay: this.editingAllDay,
        reminderMinutes: this.editingReminderMinutes,
        reminded: false
      };
      this.events = [...this.events, newEvent];
    }
    this.showEditor = false;
  }

  private deleteEvent(id: string) {
    this.events = this.events.filter((e: CalendarEvent): boolean => e.id !== id);
  }

  private addSubscription() {
    if (!this.subscriptionName || this.subscriptionName.trim() === '') {
      return;
    }
    if (!this.subscriptionUrl || this.subscriptionUrl.trim() === '') {
      return;
    }

    const newSub: SubscriptionSource = {
      id: `sub-${Date.now()}`,
      name: this.subscriptionName,
      url: this.subscriptionUrl,
      lastSync: new Date()
    };

    this.subscriptions = this.subscriptions.concat([newSub]);
    this.fetchSubscription(newSub);
    this.subscriptionName = '';
    this.subscriptionUrl = '';
  }

  private removeSubscription(id: string) {
    // 删除订阅源
    this.subscriptions = this.subscriptions.filter((s: SubscriptionSource): boolean => s.id !== id);
    // 删除该订阅源的所有事件
    this.events = this.events.filter((e: CalendarEvent): boolean => e.source !== id);
  }

  private fetchSubscription(sub: SubscriptionSource): void {
    // 网络订阅功能：模拟获取远程ICS文件
    // 注意：HarmonyOS中需要使用@ohos.net.http模块
    // 这里提供示例数据以演示功能
    const sampleIcs: string = `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:sample-${sub.id}
SUMMARY:订阅日程-${sub.name}
DTSTART:20251220T100000
DTEND:20251220T110000
DESCRIPTION:来自订阅源的示例日程
END:VEVENT
END:VCALENDAR`;
    
    // 解析示例数据
    this.parseSubscriptionIcs(sampleIcs, sub.id);
  }

  private parseSubscriptionIcs(text: string, sourceId: string) {
    if (!text || text.trim() === '') {
      return;
    }
    const lines: string[] = text.split('\n');
    let cursor: number = 0;
    let imported: CalendarEvent[] = [];

    while (cursor < lines.length) {
      const line: string = lines[cursor].trim();
      if (line === 'BEGIN:VEVENT') {
        let id: string = `${sourceId}-${Date.now()}-${cursor}`;
        let title: string = '';
        let description: string = '';
        let dtStart: Date = new Date();
        let dtEnd: Date = new Date();

        cursor++;
        while (cursor < lines.length && lines[cursor].trim() !== 'END:VEVENT') {
          const l: string = lines[cursor].trim();
          if (l.startsWith('UID:')) {
            id = `${sourceId}-${l.substring(4).trim()}`;
          } else if (l.startsWith('SUMMARY:')) {
            title = l.substring(8).trim();
          } else if (l.startsWith('DESCRIPTION:')) {
            description = l.substring(12).trim();
          } else if (l.startsWith('DTSTART:')) {
            dtStart = this.parseIcsDate(l.substring(8).trim());
          } else if (l.startsWith('DTEND:')) {
            dtEnd = this.parseIcsDate(l.substring(6).trim());
          }
          cursor++;
        }

        if (title && title !== '') {
          const ev: CalendarEvent = {
            id: id,
            title: title,
            description: description,
            startTime: dtStart,
            endTime: dtEnd,
            allDay: false,
            source: sourceId,
            reminderMinutes: 0,
            reminded: true
          };
          imported.push(ev);
        }
      }
      cursor++;
    }

    if (imported.length > 0) {
      // 先删除该订阅源的旧事件
      const filtered: CalendarEvent[] = this.events.filter((e: CalendarEvent): boolean => e.source !== sourceId);
      this.events = filtered.concat(imported);
    }
  }

  private getEventsForDate(date: Date): CalendarEvent[] {
    const filtered: CalendarEvent[] = this.events.filter((e: CalendarEvent): boolean => this.isSameDate(e.startTime, date));
    // 按起始时间排序
    filtered.sort((a: CalendarEvent, b: CalendarEvent): number => {
      return a.startTime.getTime() - b.startTime.getTime();
    });
    return filtered;
  }

  private countEventsForDate(date: Date): number {
    return this.getEventsForDate(date).length;
  }

  private getEventDotArray(date: Date): number[] {
    const count: number = this.countEventsForDate(date);
    // 有事件就显示 1 个点，没有事件就不显示
    if (count > 0) {
      return [0];
    }
    return [];
  }

  private formatTimeRange(e: CalendarEvent): string {
    if (e.allDay) {
      return '全天';
    }
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    const sh: number = e.startTime.getHours();
    const sm: number = e.startTime.getMinutes();
    const eh: number = e.endTime.getHours();
    const em: number = e.endTime.getMinutes();
    return `${pad(sh)}:${pad(sm)} - ${pad(eh)}:${pad(em)}`;
  }

  private getReminderSelectIndex(): number {
    const values: number[] = [0, 5, 15, 30, 60];
    const idx: number = values.indexOf(this.editingReminderMinutes);
    return idx >= 0 ? idx : 0;
  }

  private getReminderSelectValue(): string {
    const labels: string[] = ['不提醒', '5分钟', '15分钟', '30分钟', '1小时'];
    const idx: number = this.getReminderSelectIndex();
    return labels[idx];
  }

  private exportEventsToIcs(): string {
    let lines: string[] = [];
    lines.push('BEGIN:VCALENDAR');
    lines.push('VERSION:2.0');
    lines.push('PRODID:-//HarmonyCalendar//CN');

    const allEvents: CalendarEvent[] = this.events;
    for (let i: number = 0; i < allEvents.length; i++) {
      const e: CalendarEvent = allEvents[i];
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:${e.id}`);
      lines.push(`SUMMARY:${e.title}`);
      if (e.description) {
        lines.push(`DESCRIPTION:${e.description}`);
      }
      lines.push(`DTSTART:${this.formatIcsDate(e.startTime)}`);
      lines.push(`DTEND:${this.formatIcsDate(e.endTime)}`);
      lines.push('END:VEVENT');
    }

    lines.push('END:VCALENDAR');
    return lines.join('\n');
  }

  private importEventsFromIcs(text: string) {
    if (!text || text.trim() === '') {
      return;
    }
    const lines: string[] = text.split('\n');
    let cursor: number = 0;
    let imported: CalendarEvent[] = [];

    while (cursor < lines.length) {
      const line: string = lines[cursor].trim();
      if (line === 'BEGIN:VEVENT') {
        let id: string = `${Date.now()}-${cursor}`;
        let title: string = '';
        let description: string = '';
        let dtStart: Date = new Date();
        let dtEnd: Date = new Date();

        cursor++;
        while (cursor < lines.length && lines[cursor].trim() !== 'END:VEVENT') {
          const l: string = lines[cursor].trim();
          if (l.startsWith('UID:')) {
            id = l.substring(4).trim();
          } else if (l.startsWith('SUMMARY:')) {
            title = l.substring(8).trim();
          } else if (l.startsWith('DESCRIPTION:')) {
            description = l.substring(12).trim();
          } else if (l.startsWith('DTSTART:')) {
            dtStart = this.parseIcsDate(l.substring(8).trim());
          } else if (l.startsWith('DTEND:')) {
            dtEnd = this.parseIcsDate(l.substring(6).trim());
          }
          cursor++;
        }

        if (title && title !== '') {
          const ev: CalendarEvent = {
            id: id,
            title: title,
            description: description,
            startTime: dtStart,
            endTime: dtEnd,
            allDay: false,
            source: 'imported'
          };
          imported.push(ev);
        }
      }
      cursor++;
    }

    if (imported.length > 0) {
      this.events = this.events.concat(imported);
    }
  }

  private formatIcsDate(d: Date): string {
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    const year: number = d.getFullYear();
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const hour: number = d.getHours();
    const minute: number = d.getMinutes();
    const second: number = d.getSeconds();
    return `${year}${pad(month)}${pad(day)}T${pad(hour)}${pad(minute)}${pad(second)}`;
  }

  private parseIcsDate(s: string): Date {
    // 形如 20251211T090000
    if (!s || s.length < 15) {
      return new Date();
    }
    const year: number = Number.parseInt(s.substring(0, 4));
    const month: number = Number.parseInt(s.substring(4, 6));
    const day: number = Number.parseInt(s.substring(6, 8));
    const hour: number = Number.parseInt(s.substring(9, 11));
    const minute: number = Number.parseInt(s.substring(11, 13));
    const second: number = Number.parseInt(s.substring(13, 15));
    return new Date(year, month - 1, day, hour, minute, second);
  }

  private formatWeekDayLabel(d: Date): string {
    const weekIndex: number = d.getDay();
    const dayLabel: string = this.weekDays[weekIndex];
    const dayNum: number = d.getDate();
    return `周${dayLabel} ${dayNum}日`;
  }

  // ==== 农历计算（公历转农历，1900-2100 年有效）====

  private lunarInfo: number[] = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5d0, 0x14573, 0x052d0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b5a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x05ac0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63
  ];

  private lunarMonthDays(year: number, month: number): number {
    const info = this.lunarInfo[year - 1900];
    return (info & (0x10000 >> month)) ? 30 : 29;
  }

  private leapMonth(year: number): number {
    return this.lunarInfo[year - 1900] & 0xf;
  }

  private leapMonthDays(year: number): number {
    const info = this.lunarInfo[year - 1900];
    if (this.leapMonth(year) !== 0) {
      return (info & 0x10000) ? 30 : 29;
    }
    return 0;
  }

  private solarToLunar(date: Date): LunarDateResult {
    const baseDate: Date = new Date(1900, 0, 31); // 1900-01-31 对应农历 1900-正月初一
    let offset: number = Math.floor((date.getTime() - baseDate.getTime()) / 86400000);

    let year: number = 1900;
    let temp: number = 0;

    while (year < 2101 && offset > 0) {
      temp = this.lunarYearDays(year);
      if (offset < temp) {
        break;
      }
      offset -= temp;
      year++;
    }

    let leap: number = this.leapMonth(year);
    let isLeap: boolean = false;
    let month: number = 1;

    while (month <= 12 && offset >= 0) {
      if (leap > 0 && month === leap + 1 && !isLeap) {
        month--;
        isLeap = true;
        temp = this.leapMonthDays(year);
      } else {
        temp = this.lunarMonthDays(year, month);
      }

      if (offset < temp) {
        break;
      }

      offset -= temp;

      if (isLeap && month === leap + 1) {
        isLeap = false;
      }
      month++;
    }

    const day: number = offset + 1;
    const result: LunarDateResult = { lunarYear: year, lunarMonth: month, lunarDay: day, isLeap: isLeap };
    return result;
  }

  private lunarYearDays(year: number): number {
    let sum: number = 348;
    const info: number = this.lunarInfo[year - 1900];
    for (let i = 0x8000; i > 0x8; i >>= 1) {
      sum += (info & i) ? 1 : 0;
    }
    return sum + this.leapMonthDays(year);
  }

  private getLunarLabel(d: Date): string {
    const lunar = this.solarToLunar(d);
    const day: number = lunar.lunarDay;

    // 农历月份名称
    const monthNames: string[] = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月'];

    // 每月初一显示月份（例如：六月初一 显示为 “六月”，闰六月初一 显示为 “闰六月”）
    if (day === 1) {
      const monthIndex: number = lunar.lunarMonth - 1;
      if (monthIndex >= 0 && monthIndex < monthNames.length) {
        const prefix: string = lunar.isLeap ? '闰' : '';
        return `${prefix}${monthNames[monthIndex]}`;
      }
    }

    const baseNames: string[] = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'];
    if (day >= 1 && day <= baseNames.length) {
      return baseNames[day - 1];
    }
    return '';
  }

  private getMonthGridDates(): Date[] {
    let result: Date[] = [];
    let firstDay: Date = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth(), 1);
    let startWeekDay: number = firstDay.getDay();
    let dayCounter: number = 1 - startWeekDay;

    for (let i: number = 0; i < 42; i++) {
      result.push(new Date(this.currentDate.getFullYear(), this.currentDate.getMonth(), dayCounter));
      dayCounter++;
    }
    return result;
  }

  private getMonthCellDate(rowIndex: number, colIndex: number): Date {
    const monthCells: Date[] = this.getMonthGridDates();
    const idx: number = rowIndex * 7 + colIndex;
    return monthCells[idx];
  }

  private getWeekStartDate(): Date {
    const d: Date = this.currentDate;
    const day: number = d.getDay();
    // 以周日为一周开始
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() - day);
  }

  private getWeekCellDate(index: number): Date {
    const start: Date = this.getWeekStartDate();
    return new Date(start.getFullYear(), start.getMonth(), start.getDate() + index);
  }

  private isCellInCurrentMonth(rowIndex: number, colIndex: number): boolean {
    const d: Date = this.getMonthCellDate(rowIndex, colIndex);
    return d.getMonth() === this.currentDate.getMonth();
  }

  private isCellToday(rowIndex: number, colIndex: number): boolean {
    const d: Date = this.getMonthCellDate(rowIndex, colIndex);
    return this.isSameDate(d, new Date());
  }

  @Builder
  private buildWeekView() {
    Column() {
      // 顶部一行显示本周 7 天（仅日期数字，周几由上方星期栏展示）
      Row() {
        ForEach(this.weekIndices, (idx: number) => {
          Column() {
            Text(`${this.getWeekCellDate(idx).getDate()}`)
              .fontSize(14)
              .fontWeight(this.isSameDate(this.getWeekCellDate(idx), this.currentDate) ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.isSameDate(this.getWeekCellDate(idx), this.currentDate) ? '#111827' : '#4B5563')
          }
          .width('14.28%')
          .height(44)
          .borderRadius(12)
          .backgroundColor(this.isSameDate(this.getWeekCellDate(idx), this.currentDate) ? '#E5EDFF' : 'transparent')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.currentDate = this.getWeekCellDate(idx);
          })
        }, (idx: number) => `${idx}`)
      }
      .margin({ bottom: 12 })

      // 本周事件列表（按天排列，简洁列表样式，可滚动）
      Scroll() {
        Column() {
          ForEach(this.weekIndices, (idx: number) => {
            if (this.getEventsForDate(this.getWeekCellDate(idx)).length > 0) {
              Column() {
                // 每天的小标题
                Text(this.formatWeekDayLabel(this.getWeekCellDate(idx)))
                  .fontSize(13)
                  .fontColor('#6B7280')
                  .margin({ top: 4, bottom: 2 })

                // 这一天的事件列表
                Column() {
                  ForEach(this.getEventsForDate(this.getWeekCellDate(idx)), (event: CalendarEvent) => {
                    Row() {
                      // 左侧时间列
                      Text(this.formatTimeRange(event))
                        .fontSize(13)
                        .fontColor('#6B7280')
                        .width(100)

                      // 右侧事件信息
                      Column() {
                        Text(event.title)
                          .fontSize(14)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#111827')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')

                        if (event.description) {
                          Text(event.description)
                            .fontSize(12)
                            .fontColor('#6B7280')
                            .margin({ top: 2 })
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width('100%')
                        }
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                    }
                    .width('100%')
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .backgroundColor(Color.White)
                    .borderRadius(8)
                    .margin({ bottom: 8 })
                    .onClick(() => {
                      this.openEditEventEditor(event);
                    })
                  }, (event: CalendarEvent) => event.id)
                }
              }
              .margin({ bottom: 6 })
            }
          }, (idx: number) => `week-list-${idx}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .height(500)
      .margin({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
  }

  @Builder
  private buildDayView() {
    Column() {
      // 顶部日期说明
      Row() {
        Column() {
          Text(this.formatDateLabel(this.currentDate))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
          Text('当天所有日程')
            .fontSize(12)
            .fontColor('#6B7280')
            .margin({ top: 2 })
        }
      }
      .margin({ bottom: 12 })

      // 当天事件列表（可滚动）
      Scroll() {
        Column() {
          if (this.getEventsForDate(this.currentDate).length === 0) {
            Text('这一天暂时还没有日程')
              .fontSize(16)
              .fontColor('#4B5563')
              .textAlign(TextAlign.Center)
              .margin({ top: 24 })
          } else {
            ForEach(this.getEventsForDate(this.currentDate), (event: CalendarEvent) => {
              Row() {
                // 左侧时间列
                Text(this.formatTimeRange(event))
                  .fontSize(13)
                  .fontColor('#6B7280')
                  .width(100)

                // 右侧事件信息
                Column() {
                  Text(event.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#111827')
                    .width('100%')

                  if (event.description) {
                    Text(event.description)
                      .fontSize(13)
                      .fontColor('#6B7280')
                      .margin({ top: 2 })
                      .width('100%')
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor(Color.White)
              .borderRadius(8)
              .margin({ bottom: 8 })
              .onClick(() => {
                this.openEditEventEditor(event);
              })
            }, (event: CalendarEvent) => `day-${event.id}-${event.title}-${event.startTime.getTime()}`)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .height(500)
      .margin({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
  }

  private isSameDate(a: Date, b: Date): boolean {
    return a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate();
  }

  private formatDateLabel(date: Date): string {
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const week = this.weekDays[date.getDay()];
    return `${year}年${month}月${day}日 · 周${week}`;
  }
}