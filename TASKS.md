# Orbit — активная очередь

2026-10-13: iOS первым, local-first. Пользователь одобрил направление концепта: удобство задач Todoist и календаря TickTick, Today Список/Расписание; Календарь День/3 дня/Месяц, без Недели. Концепт не равен реализованному календарю.

| TASK | Статус | Один результат |
| --- | --- | --- |
| NATIVE-001 | NEEDS_FIXES / PAUSED | macOS R1 explicit store path открыт; core/macOS base импортирован как зависимость NATIVE-002, задача macOS не DONE |
| NATIVE-002 | DONE (Inbox scope) | локальный iOS Inbox, build/core20, Simulator evidence; main merge14a9778, интеграционные build/core20 PASS; реальный iPhone не проверен |
| NATIVE-003 | DONE | назначить/изменить/убрать дату task в iOS Inbox, disk persistence и сохранность старых stores |
| NATIVE-004 | DONE | shared core интервала: core50/iOS build/legacy upgrade/7200 civil oracle PASS; UI отдельно |
| NATIVE-005 | DONE | iOS interval editor, R1 title закрыт, build/GUI evidence; локальный merge6d12ae2 |
| NATIVE-006 | DONE | Today list + две настоящие вкладки, R1 видимые write errors; merge8b36067 |
| NATIVE-007A | DONE | read-only проекция интервалов на сутки, включая переход через полночь |
| NATIVE-007B | DONE | календарный День с временной сеткой на принятой проекции |
| NATIVE-007C | DONE | раскрываемая область «Без времени»: 3 строки / больше / внутренний scroll |
| NATIVE-NAV-001 | DONE | Today Список/Календарь, убрать самостоятельную Calendar tab |
| NATIVE-NAV-002 | DONE | реальный раздел Предстоящее с List/Calendar над shared tasks |
| NATIVE-LIST-001 | DONE | меню даты/времени/длительности по tap, без иконок, компактнее обычные list строки |
| NATIVE-MIN5 | DONE | core write минимум5минут, legacy1–4неперезаписывать/readgeometryсохранить |
| NATIVE-UI-MODE | DONE | единая позиция и оформление view switcher в Today/Upcoming обоих видах |
| NATIVE-TIME-WHEEL | DONE | начало/длительность нативными колёсиками, derived конец без нового storage |
| NATIVE-ADD-001 | DONE | атомарное создание с optional date; маленький core prerequisite |
| NATIVE-ADD-002 | DONE | общий + и create sheet в Inbox/Today/Upcoming, убрать Inbox composer, спокойное empty Today |
| NATIVE-EDIT-001 | DONE | core rename/delete поUUID безпереписыванияschema |
| NATIVE-ADD-003 | DONE | atomiccreateoptionalinterval вcore, безUI |
| NATIVE-ADD-004 | DONE | editabledate/start/duration вsharedcreatesheet |
| NATIVE-EDIT-002 | DONE | native rename/delete UI сconfirm иCancel |
| NATIVE-DEVICE-001 | INSTALLED / USER-CONFIRMED LAUNCH | установлен на личный iPhone; пользователь подтвердил запуск, полный physical smoke не заявляется |
| NATIVE-FAB-R1 | IMPLEMENTED / OWNER CHECK | увеличенная стабильная «+», первый tap календаря, сильнее haptics, Settings без предварительной заливки |
| NATIVE-GESTURES-R1 | IMPLEMENTED / OWNER CHECK | маленькие точки с прежним offsets, tap пустой сетки снимает selection, согласованная dark Form |
| NATIVE-TASK-GESTURES | IMPLEMENTED / OWNER CHECK | общий preview списка, календарные move/start/end handles; 93 core tests, Simulator gestures |
| NATIVE-CALENDAR-PREVIEW | IMPLEMENTED / OWNER CHECK | карточка над действиями по tap, исходный блок остаётся в сетке; отчёт и Simulator evidence |
| NATIVE-UI-FEEDBACK-001 | IMPLEMENTED / OWNER CHECK | интерфейс и баги из ZIP; Simulator smoke и builds, ограничения в отчёте |
| NATIVE-PRJ-001 | IMPLEMENTED / SELF-CHECK | core list/create/rename, 98/98 tests, previous-source disk upgrade и iOS build PASS; UI отдельно |
| NATIVE-PRJ-002 | IMPLEMENTED / SELF-CHECK | вкладка, create/rename, dark/AXL/relaunch и store-сохранность PASS; swipe UNVERIFIED |
| NATIVE-PRJ-003 | IMPLEMENTED / SELF-CHECK | membership, atomic create, 101/101, previous-source upgrade PASS |
| NATIVE-DEADLINE-001 | IMPLEMENTED / SELF-CHECK | независимый civil-дедлайн, create/edit/clear, overdue и additive upgrade |
| NATIVE-PRJ-004 | IMPLEMENTED / SELF-CHECK | папки List/Calendar, picker, единый gear/header, нижний FAB, GUI/store/relaunch PASS |
| NATIVE-007D | TODO (план) | перенос из «Без времени» в сетку, отдельный scope перед выдачей |
| NATIVE-007E | TODO (план) | изменение длительности жестом |
| NATIVE-007F | TODO (план) | плавная компоновка пересекающихся интервалов |
| NATIVE-007G | TODO (план) | спокойные пустые состояния с орбитой и русской датой |
| NATIVE-008 | TODO (план, не назначен) | 3 дня на общей шкале времени |
| NATIVE-009 | TODO (план, не назначен) | календарный Месяц |

NATIVE-004 принят и локально интегрирован; NATIVE-005 принят, NATIVE-006 принят; 007A принят; назначен только tasks/NATIVE-007B.md в task/NATIVE-007B, worktree /Users/atlhnv/Codex/orbit-worktrees/NATIVE-007B. NATIVE-003 закрыт. Время/длительность разбиты на core и отдельный editor, чтобы не наращивать TASK. Следующие строки — ориентир, их scope уточняется перед выдачей; не реализовывать очередь целиком. Реальная навигация добавляется с готовыми экранами, без фиктивных календарных вкладок. Нативные проекты/rename/delete/backup — отдельные последующие маленькие задания; не забыты. Web/сервера/sync PAUSED. macOS дизайн позже, macOS-R1 не потерян.

Первичное review NATIVE-0032026-10-13: core30/iOS build/legacy upgrade PASS, один R1 в Gregorian UI adapters. Выдан tasks/NATIVE-003-R1.md в task/NATIVE-003; остальные функции не назначены. Полный review в reports/NATIVE-003.md task worktree.

Итог NATIVE-0032026-10-13: R1 закрыт, product7baab2c независимо core31/iOS build PASS; legacy upgrade проверен ранее. Main merge762e7ad257e156cef5b485a58d831d6881ca1281, native source идентичен проверенной ветке. GUI смены даты/реальный iPhone остаются непроверенными. NATIVE-004 пока план, macOS-R1 PAUSED; push/deploy не выполнялись.

Назначение2026-10-13: NATIVE-004 только3product core files + targeted tests, без UI. Изначальные будущие номера005–008 были планом без assignment; уточнены005editor/006Today/007Day/008Three/009Month. Последующие файлы/ветки не выданы.

Итог2026-10-13: NATIVE-004 DONE, product40f1b20 независимо core50/iOS build/legacy upgrade/7200 civil oracle PASS; локальный mergebd4984eba8a9e23b748bf017499e7bd3b1f41952. Native sources main совпадают с протестированной веткой. UI editor/реальный iPhone/runtime save failure не проверялись; NATIVE-005 не назначен, push/deploy отсутствуют.

Назначение2026-10-13: NATIVE-005 — только iOS interval editor поверх принятого core (source base a56137473b186efe5b87d4ae9c46881f092262df). Следующий NATIVE-006/Today не назначен. По уточнению пользователя после принятия задачи сразу выдавать следующий небольшой prompt.

Review2026-10-13: NATIVE-005 aa22fdc — одна R1: название задачи отсутствует в interval sheet. Независимый iOS build и экранный ввод23:30 + отказ25:00 без мутации PASS. Назначен tasks/NATIVE-005-R1.md только в task worktree, coordinator HEAD d3edd9abbe1f25607c8122055e953e5f27ca74cd. Без merge; NATIVE-006 не выдан.

Итог2026-10-13: NATIVE-005 DONE после R1, source961cc2d; main merge6d12ae26e3c145ccd9041efde7bf6dc443447e1f. Независимые iOS build/экранный ввод времени/invalid rejection PASS; title screenshot/source проверены. Реальный iPhone не проверен. Следующий NATIVE-006 — небольшой Today list; календарь позже.

Назначение2026-10-13: NATIVE-006 Today list, source base800b189adc9442d980cb8fb5080aa5e42efa0ff7. Only plannedDate==local today, open/completed sections; две реальные native вкладки, один store/model. Quick-add остаётся в Inbox, календарные режимы не назначены.

Review2026-10-13: NATIVE-006917f960 независимо core56/iOS build PASS. Один R1: writeError не отображается на Today; tasks/NATIVE-006-R1.md назначен только в task worktree, correction start6610a5accaf1024eeb3bc6c85de14d1081c256c5. Без merge, NATIVE-007 не выдан.

Итог2026-10-13: NATIVE-006 принят после R1, локальный merge8b360670035f77612eec6792f40449cf10916892. Core56/iOS build до коррекции, targeted6/iOS build после коррекции PASS; shared source identity после merge PASS. Runtime banner/real iPhone не проверены. NATIVE-007 разделён на маленькие007A projection и007B grid UI, без гигантского задания на весь календарь.

Назначение2026-10-13: NATIVE-007A только one-file projection helper+targeted tests, source base2b14c779ad2abff50e6b30bc87457c8f9e580fb2. Minute segments0...1440, positive overnight continuation; без lanes/UI/миграций.007B grid UI пока не назначен.

Review2026-10-13: NATIVE-007A1e53a77 independently core66 PASS, но точная midnight граница помечается продолжением и UUID-test ошибочно игнорирует end-priority. Fixed-ID probe воспроизводит обе находки; назначен один tasks/NATIVE-007A-R1.md в task worktree, correction startde64a83364b310d82fa251e3a1ca032de8af2137. Без merge/007B.

Итог2026-10-13: NATIVE-007A принят после R1/R2, productaddcfd3, main merge9c499d4e81c251b2f8c2b93d70ff94202a374a88. Независимые11targeted/iOS build после fix PASS;66full ранее до fix, полный67 после fix не запускался. Calendar UI пока отсутствует, следующий007B только Day screen.

Назначение2026-10-13: NATIVE-007B только Day grid UI, source baseaaa01d42cd5196dff246a863270d61c2a2472766. Core неизменен, три iOS файла, native Calendar tab и existing editors;3days/Month/drag/AI не входят. После первого рабочего Day предполагается editing/delete и device QA; дальнейший порядок уточняется по личному тестированию.

Review2026-10-13: NATIVE-007B5d9bcb5 independent iOS build PASS, но own GUI12untimed теряет сетку/date controls; width probe8lanes536pt на402viewport; short visual height != duration. Один tasks/NATIVE-007B-R1.md на2UIfiles, correction start4aa3b893e69b78466058c58fcfe818fb600ea0e8. Tap/context/evening GUI UNVERIFIED, без merge/next TASK.

Повторное review2026-10-13: productfa7e520 независимо iOS build PASS; R1 untimed/R2 fitting закрыты. R3 floor2pt оставляет overlap0.933pt для1minute; исчезли все visible labels/continuation. Один tasks/NATIVE-007B-R1b.md: DayTimelineView+отчёт, start16fa7eb71e712bb4540288e0997faa767e7f753c. Readable labels/exact paint/native menu, без merge/next TASK.

Итог2026-10-14: NATIVE-007B принят, productba3b3e9, main merge5e5274964465142093471535d7618ddda34d07fb. Independent latest iOS build PASS, main apple/ identity с tested branch PASS; latest GUI screenshot/executor evidence reviewed, own latest GUI не повторялся, real-device/context-menu/late pixel ограничения сохранены. Назначен только007C, source base5e52749. Последовательность пользовательских улучшений: untimed collapse → drag → resize → overlap animation; empty-state redesign сохранён отдельным планом.3days/Month/AI не начинать.

Review2026-10-14: NATIVE-007C71b4c38 independent iOS build PASS; fixed260/double toggle sizing и report GUI claims без actual evidence требуют R1. Назначен только tasks/NATIVE-007C-R1.md в task worktree, startc0332cf9276135194acb2a43144861c3ffa625d7. Без merge/next TASK.

Уточнение2026-10-14: пользователь просит компактный верх/chips по IMG_1210. R1 implementation46e755d ещё не принята; назначен один tasks/NATIVE-007C-R2.md поверх неё, start120e2cf28eb2ecc61d42998c4c3e506291ff48e5. Итоговый независимый review cumulative R1+R2. Без merge,007D не выдан.

Уточнение2026-10-14: во время WIP R2 пользователь подтвердил ещё3UX пункта (плотность rows/circle внутри/menu около даты). Подготовлен NATIVE-007C-R3 в /Users/atlhnv/Codex/orbit-outputs/NATIVE-007C-R3.md. Сначала GLM завершает R2 обычным commit, затем clean tree и full SHA R2 — start R3. Scope3UI files, только compact rows/menu move, no grid/core rewrite. Итог cumulative review R1/R2/R3;007D не назначен. Незакоммиченные R2 файлы координатор не менял.

План2026-10-14 по прямому решению пользователя: NATIVE-MIN5 — минимум новой/изменяемой duration5минут, legacy1–4 не перезаписывать/не скрывать. Отдельный небольшой core/editor TASK после принятия007C, перед drag; подготовленный scope /Users/atlhnv/Codex/orbit-outputs/NATIVE-MIN5.md, branch/worktree ещё не назначены. R3 WIP не расширяется.

Cumulative review2026-10-14: NATIVE-007C9cefc4d independentiOSbuild/diffcheck PASS; compactcards/menu/sourceidentity reviewed. Одна tinyFINAL в CalendarDayScreen: conditional directions upper↑↓ lower↓↑, не180rotation symmetricpair; boundedemptygutter. Tasks/NATIVE-007C-FINAL.md в taskworktree, correctionstartc8b6f8cb87a8376671f55d595c502c158863ebef. No merge/min5branchuntilacceptance; последующийTASK=NATIVE-MIN5.

Приоритет2026-10-14 уточнён пользователем: отдельный Calendar tab запрещён, Today и Upcoming должны иметь List/Calendar views. После закрытия007C→NAV001→NAV002→MIN5→drag/resize/overlap. Подробный bounded план /Users/atlhnv/Codex/orbit-outputs/NATIVE-NAV-plan.md; новые branches пока не выданы. Раньше объявленная очередь MIN5 immediately next заменена этим прямым уточнением.007C final build/review остаются про renderer, не acceptance неправильной продуктовой навигации.

Итог2026-10-14:007C acceptedfinalfe8e58d/mainmergeb5608d1eaace8f4d8793c5eff36ed4caa1bc0e23, independentiOSbuildPASS, mainapple/identitytestedbranchPASS. Reportedrestart→deviceQA, pan/longpress/realdeviceнеподтверждены. Следующий назначенNAV001Todaymodes/removeCalendartab, sourcebaseb5608d1;NAV002realUpcomingпотом, неrenameCalendar. Минимум5/dragневыданы.

Итог2026-10-14: NAV001 accepted58ae60a, main mergebe6d6abbffeefe9fc76a8fa2cbc43fb3bec86cec; independentiOSbuild/diffcheck PASS, mainapple identity testedbranch. P3 datecaption locale tracked NAV002. Следующий NAV002 realUpcoming: List7inclusive/calendarDay, owner selectedday+mode; near2199 list windowtruncate, nofakeCalendarTab/core changes/3days. Источникbasebe6d6abb; MIN5/drag не выданы.

Уточнение2026-10-14: пользователь назначил listrowmenu/no icons/lessheight. NAV002сейчасWIP (егофайлыкоординаторнетрогает); следующийпослеегоreview NATIVE-LIST-001, затемMIN5/drag. Boundedplan /Users/atlhnv/Codex/orbit-outputs/NATIVE-LIST-001.md, no assignedbranchyet. Этоlistrowheight, не taskduration/calendargeometry.

Прямое уточнениеNAV0022026-10-14: contextual «Сегодня» тольконавыбранномнесегодняшнемдне вList/Calendar. Supplementalprompt /Users/atlhnv/Codex/orbit-outputs/NATIVE-NAV-002-today-button-prompt.txt. Никакихproductправоккоординатором/WIPперезаписей, branchscopeпрежний.

Приоритет2026-10-14: пользователь добавил bottomProjects. Подготовлен /Users/atlhnv/Codex/orbit-outputs/NATIVE-PROJECTS-plan.md, splitcore→realUI→taskassignment. ПослеNAV002/listrow/MIN5 выдатьпоодномуPRJtask передgesturepolish; currentNAV002нерасширяется/schemaнеправитсявегоWIP. No fakeProjects tab/большойTASKвесьprojectroadmap.

Review2026-10-14: NAV002185a19b independentiOSbuild/diffcheckPASS, но contextualToday отсутствует вbothviews и Calendarfallback слишкомwide (actualscreenshot04mode/hourlabelsclipped). Одинheadercorrection tasks/NATIVE-NAV-002-R1.md на3UI files, start322b55761f6fcfb83c625e4a23d9874e784963d9. Membership/range/sharedselectionsource reviewed, no merge/LIST001branchyet.

Итог2026-10-14: NAV002 accepted8551416/mainmerge8547b026986aa563ef31751521f23587642cb51d, independentiOSbuildPASS/mainapple sourceidentityPASS. R1/R2closed, runtime6buttonstates executor evidence reviewed/ownlatestGUIнеповторялся. Current nextLIST001 sourcebase8547b026 (actual assignmenttasksfile). Unifiedmodeheader position отдельноplanned поuser«дальшеисправим/покаwait», не блокируетLIST001 иscopeнерасширяет.

Итог2026-10-14: LIST001 acceptededf45db/mainmerge12fbee7dc651128fa1aa829570180f15c2cd92be, independentiOSbuildPASS/sourceidentityaftermergePASS. Native Menu/bodyhit/circle independent/undatedgating/dateflag/noicon reviewed, source+executorGUIexplicit. NextMIN5 sourcebase12fbee7, actualtasks/NATIVE-MIN5.md; Projects/commonheader/gestures планы не выданы.

Уточнение2026-10-14: послеMIN5 маленькийUItimewheel editor вместоkeyboard, plan /Users/atlhnv/Codex/orbit-outputs/NATIVE-TIME-WHEEL-plan.md. MIN5scopeнерасширять, nonewcore schema. Doublecontour switcher поправитьвNATIVE-UI-MODE вместе сcommonplacement, existingplansнепотеряны.

Итог2026-10-14: MIN5accepted/mainmerge8e2abbd74c8bdbb6de66e9f2064b4a96feda2320, independent70tests/iOSbuildPASS/sourceidentityPASS. NextTIME-WHEEL UIonly. Прямоеlatestuserуточнение: durationminuteswheel ONLY0/5/10…55, hoursseparate; coreнестановитсякратностью5, old6/7readremain. LegacyoffgridUIexplicitchoice, no silentnormalization. Projects/header/gesturesневыданы.

Итог2026-10-14: TIME-WHEEL принят/productf1a952c/mainmergee4f304e3d5a133108bf5c870855d7d43f5e4c9dc, independentiOSbuildPASS/sourceidentityPASS. NextUI-MODEтолькоswitcherplacement/doublecontour, no redrawвсехscreen. Startwheelstep5 userотменил:minutes0..59прежние. Futuredragstartstep5, resizeallowed5/10/20/30…; corewrite/readunchanged. ProjectsдалееотдельнымималенькимиTASK.

Review2026-10-14: UI-MODE2c33ac3/reportf3b9ce9 independentiOSbuild/diffcheckPASS. Doublecontour закрыт, но actual4screens/source показывают скачок control: inline navigation title толькоList, Calendarbarсхлопывается; NativeModeHeader отсутствует вCalendar, дополнительныеinsetsUpcoming. Назначен один tasks/NATIVE-UI-MODE-R1.md в тойжеtaskветке, start e323adf0e6e3efc9815ff363d8c01b59e12d1a6d. Без merge/Projects.

Уточнение пользователя2026-10-14 к UI-MODE-R1: Today List без верхнего заголовка «Сегодня»; control поднять в освобождённое место на уровень Calendar, дату сохранить. Обновлённый correction start449c8134f2a2fb521e8087b2fe6a409cd6728c6b; scope прежний.

Приоритет пользователя2026-10-14: после UI-MODE-R1 создание из всех3разделов (Today/Upcoming обоихвидов), FAB+ над tabbar; Inbox composer убрать. Today preset local today, Inbox nil, Upcoming selectedDay предложено. Маленькие ADD001atomiccore→ADD002sharedUI/emptyToday, затемProjects. План /Users/atlhnv/Codex/orbit-outputs/NATIVE-ADD-plan.md; branches ещё не назначены, current WIP не расширять.

Итог2026-10-14: UI-MODE accepteda9a4631/report47ce24a, mainmerge28aa41f9048991e6b2aafb571767e1aba6590c28, independentiOSbuildPASS/mainappleidentityPASS. Header/title/padding R1 закрыт; realdevice/VoiceOver/scrollstates непроверены. Назначен только ADD001 optional-date atomic create, scope2core/testfiles; sourcebase28aa41f. ADD002 shared UI следующим после приёмки; Projects ещё не назначен.

Итог2026-10-14: ADD001f72890f принят, mainmerge7c543fe7f459a6721338b4033243f43257e6bd35; independenttargeted30/iOSbuildPASS/appleidentityPASS. Назначен только tasks/NATIVE-ADD-002.md (shared FAB/form+Inboxcomposer removal+emptyToday), sourcebase7c543fe7. Core/prj/gestures не расширять. Следом для личной рабочей версии rename/delete и realdeviceQA по отдельным заданиям; Projects после базового личного прототипа либо по новому приоритету пользователя.

Итог2026-10-14: ADD0028b5aea6 принят/mainmerge5cf43a9b7ab6a762c498e505d37bf07bea84112d, independentiOSbuild/ownCUAkeyboardretryCancelAXL/sourceidentityPASS. Датывсехсекций/persistenceexecutor evidence reviewed; densebottom/realdeviceUNVERIFIED. НазначенEDIT001coreCRUD только3files, UIconfirmationпотомEDIT002. FinalQA включаетFAB/footerreachability, Upcomingemptycopy иREADMEheaderdocs.

Приоритетuser2026-10-14: после текущегоEDIT001 добавитьdate/start/durationприcreate (atomiccore prerequisite затемsharedUI, отдельноневыданныеTASK), затемEDIT002UI и перваяiPhoneпроверка. Дедлайны/date+optionaltime, reminderchoices/localiOSnotifications послепервойпроверки, serverне нужен. CurrentEDIT001нерасширять. План /Users/atlhnv/Codex/orbit-outputs/NATIVE-FIRST-IPHONE-plan.md.

Review2026-10-14: EDIT00184f6048 independent36/iOSbuildPASS, одна R1publicsetTitle rawbypass противTASK. Убратьpublic/internalOrbitCore; store/tests unchanged, одинbuild послеfix. tasks/NATIVE-EDIT-001-R1.md, correctionstartbf53794fd610f75e58780c9bf4b7421fec598df4. Безmerge/nextassignedtask.

Итог2026-10-14: EDIT0012bccf59 принят/mainmerge84672116c6cb05c89f793e7113d81cc444ee64fb. R1internalsetter/source/iOSbuildPASS,36suite ранееR0PASS, повторне нужен. NextassignedADD003coreatomicintervalcreation, actualtasksfile/sourcebase84672116; ADD004UIследом, затемEDIT002/deviceQA.

Итог2026-10-14: ADD00388207a3 accepted/mainmerge55ca03221ae23d938b9534e8c2a93b63696f888f; independent44/iOSbuildPASS/appleidentityPASS. НазначенADD004sharedcreateform editabledate/time/duration, sourcebase55ca032; scope2UIfiles+optionalhelper/report, core/existingeditorsне трогать. ДалееEDIT002/deviceQA, deadlines/notificationsпослеfirstiPhonecheck.

Review2026-10-15: ADD004867a0a1 independentiOSbuild/diffcheckPASS. SourceR1optionaldateonlyonChange: невозможноподтвердитьshownvalueбезпрокруткиInbox/reselectafterclear. Назначенtasks/NATIVE-ADD-004-R1.md, correctionstartd62df0c665b5c29bd22e46ac7c53b4d95f1af688; oneUIfix+report/targetedGUI/onebuild, безfullQA. No merge/EDIT002пока.

Итог2026-10-15: ADD004591396faccepted/mainmerge9a16ea0041601eb12c15be040493453e8fd074d1. IndependentR1buildPASS/sourceidentityPASS; dateconfirmGUIexecutorreviewed/softwarekeyboardunverified. Назначен EDIT002sharedlistrowrename/deleteconfirmation, sourcebase9a16ea; CalendareditчерезList, безcontextmenuscope. ПослеacceptancefirstiPhoneQA, deadlines/remindersпозже.

Итог2026-10-15: EDIT00279e180faccepted/mainmerge4c97c6da5e9e8726dc7d5edf5194ff69704f618f; independentiOSbuild/appleidentityPASS, executorGUIreviewed. НазначенDEVICE001docs/preflight/owner-assisteddeviceQA, sourcebase4c97c6da. Currentphysical0/projectTeamnone; noautomaticAppleID/signingsetup/appwipe. Перваяреальнаяустановкаещёнесостоялась.


2026-10-17: NATIVE-REMINDER-001 NEEDS_FIXES — core/UI/scheduler сохранены в task branch; 110 tests/build PASS, real delivery failure unresolved. См. reports/NATIVE-REMINDER-001-executor.md.


2026-10-17 продолжение: NATIVE-REMINDER-001 DONE по self-check, real delivery при завершённом процессе PASS (04-delivered-process-terminated.png). Прежний runtime gate закрыт после reboot own Simulator; причина исходного отказа не установлена. Core110/build прежние PASS, продуктовый код не менялся. Физическая проверка и ограничения — в отчёте.
