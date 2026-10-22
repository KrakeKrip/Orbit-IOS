// Synthetic fixture only. Compile alongside OrbitCore sources; not part of the app target.
import Foundation
@main struct Fixture {
 @MainActor static func main() throws {
  precondition(CommandLine.arguments.count == 2, "Pass a new temporary store path")
  precondition(CommandLine.arguments[1].hasPrefix("/private/tmp/"), "Use an isolated temporary directory")
  precondition(!FileManager.default.fileExists(atPath: CommandLine.arguments[1]), "Never reuse an existing store")
  let store = try OrbitTaskStore(storeURL: URL(fileURLWithPath: CommandLine.arguments[1]))
  let day = TaskDaySelection.currentDay()
  let project = try store.addProject(name: "Студия · долгосрочный проект по обновлению приложения")
  for name in ["Подготовить материалы", "Прочитать главу", "Позвонить в мастерскую", "Разобрать заметки", "Продумать план", "Выбрать маршрут", "Заказать материалы", "Проверить макеты", "Описать результат"] {
   _ = try store.addTask(title: name, plannedDate: day, projectID: project.id)
  }
  _ = try store.addTask(title: "Собрать идеи для нового проекта, обсудить детали и подготовить подробный план работы", plannedDate: day, plannedTime:"10:00", durationMinutes:120, projectID:project.id, deadlineDate:day, reminderAt:Date(timeIntervalSince1970: ceil(Date.now.timeIntervalSince1970 / 60) * 60 + 600))
  _ = try store.addTask(title: "Короткий звонок", plannedDate:day, plannedTime:"10:00", durationMinutes:5)
  _ = try store.addTask(title: "Сверить расписание", plannedDate:day, plannedTime:"10:05", durationMinutes:5)
  _ = try store.addTask(title: "Встреча с командой", plannedDate:day, plannedTime:"11:00", durationMinutes:60)
  let done = try store.addTask(title: "Проверить выполненные задачи", plannedDate:day, plannedTime:"13:00", durationMinutes:60)
  try store.setCompleted(true, for: done.id)
  _ = try store.addTask(title:"Ночная работа над иллюстрациями", plannedDate:day, plannedTime:"23:00", durationMinutes:180)
  _ = try store.addTask(title:"Задача без даты · составить список книг")
  _ = try store.addTask(title:"Отправить документы", plannedDate:"2026-10-15", deadlineDate:"2026-10-17")
  print("synthetic tasks: \(try store.tasks().count), date: \(day)")
 }
}
