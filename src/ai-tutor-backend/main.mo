import Array "mo:base/Array";
import Error "mo:base/Error";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";

import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

shared ({ caller = creator }) actor class () {
  type Question = {
    questionText: Text;
    options: [Text];
    correctAnswerIndex: Nat;
  };

  type User = {
    id: Nat;
    name: Text;
    role: Text; // "student", "teacher", or "none"
  };

  type Quiz = {
    questions: [Question];
    id: Nat;
  };

  type Lesson = {
    id: Nat;
    title: Text;
    content: Text;
    quiz: ?Quiz;
  };

  type Module = {
    id: Nat;
    title: Text;
    lessons: [Lesson];
    teacherId: Nat;
    teacherName: Text;
  };

  type StudentProgress = {
    studentId: Nat;
    moduleId: Nat;
    lessonId: Nat;
    completed: Bool;
    quizScores: [(Nat, Nat)];
  };

  type Teacher = {
    id: Nat;
    name: Text;
    modules: [Nat];
  };

  type Student = {
    id: Nat;
    name: Text;
    progress: [StudentProgress];
  };

  type Announcement = {
    id: Nat;
    content: Text;
    date: Text;
    moduleId: Nat;
  };


  type State = {
    var modules: [Module];
    var teachers: [Teacher];
    var students: [Student];
    var announcements: [Announcement];
    var users: [User];
  };

  private var state: State = {
    var modules = [];
    var teachers = [];
    var students = [];
    var announcements = [];
    var users = [];
  };

  // Counters for generating IDs
  private var moduleIdCounter: Nat = 0;
  private var lessonIdCounter: Nat = 0;
  private var quizIdCounter: Nat = 0;
  private var announcementIdCounter: Nat = 0;
  private var teacherIdCounter: Nat = 0;
  private var studentIdCounter: Nat = 0;

  stable var uploadedFile: ?Blob = null;

  public func addTeacher(name: Text): async () {
    // Check if the name is already taken
    if (Array.find(state.users, func(u: User) : Bool { u.name == name }) != null) {
      throw Error.reject("Name already exists");
    };
    let newTeacher: Teacher = {
      id = teacherIdCounter;
      name = name;
      modules = [];
    };
    let newUser: User = {
      id = teacherIdCounter;
      name = name;
      role = "teacher";
    };
    state.teachers := Array.append(state.teachers, [newTeacher]);
    state.users := Array.append(state.users, [newUser]); // Add user to users array
    teacherIdCounter += 1;
  };

  public func addModule(teacherId: Nat, title: Text, lessons: [Lesson]): async () {
    let teacherOpt = Array.find(state.teachers, func(t: Teacher) : Bool { t.id == teacherId });
    switch (teacherOpt) {
      case (null) {
        throw Error.reject("Teacher not found");
      };
      case (?teacher) {
        let newModule: Module = {
          id = moduleIdCounter;
          title = title;
          lessons = lessons;
          teacherId = teacherId;
          teacherName = teacher.name;
        };
        state.modules := Array.append(state.modules, [newModule]);
        moduleIdCounter += 1;
      };
    };
  };
  
  public func addLesson(teacherId: Nat, moduleId: Nat, title: Text, content: Text, quiz: ?Quiz): async () {
    let teacherOpt = Array.find(state.teachers, func(t: Teacher) : Bool { t.id == teacherId });
    switch (teacherOpt) {
      case (null) {
        throw Error.reject("Teacher not found");
      };
      case (?teacher) {
        let newLesson: Lesson = {
          id = lessonIdCounter;
          title = title;
          content = content;
          quiz = quiz;
        };
        let updatedModules = Array.map(state.modules, func(m: Module) : Module {
          if (m.id == moduleId) {
            return {
              id = m.id;
              title = m.title;
              lessons = Array.append(m.lessons, [newLesson]);
              teacherId = m.teacherId;
              teacherName = m.teacherName;
            };
          } else {
            return m;
          }
        });
        state.modules := updatedModules;
        lessonIdCounter += 1;
      };
    };
  };

  public func setQuiz(moduleId: Nat, lessonId: Nat, questions: [Question]): async () {
    var quizSet: Bool = false;
    let newQuiz: Quiz = {
      questions = questions;
      id = quizIdCounter;
    };
    let updatedModules: [Module] = Array.map(state.modules, func (m: Module) : Module {
      if (m.id == moduleId) {
        let updatedLessons: [Lesson] = Array.map(m.lessons, func (l: Lesson) : Lesson {
          if (l.id == lessonId) {
            quizSet := true;
            return {
              id = l.id;
              title = l.title;
              content = l.content;
              quiz = ?newQuiz;
            };
          } else {
            return l;
          }
        });
        return {
          id = m.id;
          title = m.title;
          lessons = updatedLessons;
          teacherId = m.teacherId;
          teacherName = m.teacherName;
        };
      } else {
        return m;
      }
    });
    state.modules := updatedModules;
    quizIdCounter += 1;
    if (not quizSet) {
      throw Error.reject("Quiz not set");
    }
  };


  public func getModules(): async [Module] {
    return state.modules;
  };

  public func getQuizQuestionsByLesson(moduleId: Nat, lessonId: Nat, quizId: Nat): async ?([Question], [[Text]]) {
    let moduleOpt = Array.find(state.modules, func(m: Module) : Bool { m.id == moduleId });
    switch (moduleOpt) {
      case (null) { return null; }; // Module not found
      case (?foundModule) {
        let lessonOpt = Array.find(foundModule.lessons, func(l: Lesson) : Bool { l.id == lessonId });
        switch (lessonOpt) {
          case (null) { return null; }; // Lesson not found
          case (?foundLesson) {
            switch (foundLesson.quiz) {
              case (null) { return null; }; // Quiz not found
              case (?foundQuiz) {
                if (foundQuiz.id != quizId) { return null; }; // Quiz ID mismatch
                let questions = foundQuiz.questions;
                let options = Array.map(questions, func(q: Question) : [Text] {
                  q.options
                });
                return ?(questions, options);
              };
            };
          };
        };
      };
    };
  };

  public func getQuizQuestionsByLessonAdmin(moduleId: Nat, lessonId: Nat, quizId: Nat): async ?([Question], [[Text]], [Nat]) {
    let moduleOpt = Array.find(state.modules, func(m: Module) : Bool { m.id == moduleId });
    switch (moduleOpt) {
      case (null) { return null; }; // Module not found
      case (?foundModule) {
        let lessonOpt = Array.find(foundModule.lessons, func(l: Lesson) : Bool { l.id == lessonId });
        switch (lessonOpt) {
          case (null) { return null; }; // Lesson not found
          case (?foundLesson) {
            switch (foundLesson.quiz) {
              case (null) { return null; }; // Quiz not found
              case (?foundQuiz) {
                if (foundQuiz.id != quizId) { return null; }; // Quiz ID mismatch
                let questions = foundQuiz.questions;
                let options = Array.map(questions, func(q: Question) : [Text] {
                  q.options
                });
                let answers = Array.map(questions, func(q: Question) : Nat {
                  q.correctAnswerIndex
                });
                return ?(questions, options, answers);
              };
            };
          };
        };
      };
    };
  };

  public func addAnnouncement(content: Text, date: Text, moduleId: Nat): async () {
    let newAnnouncement: Announcement = {
      id = announcementIdCounter;
      content = content;
      date = date;
      moduleId = moduleId; // Set the moduleId field
    };
    state.announcements := Array.append(state.announcements, [newAnnouncement]);
    announcementIdCounter += 1;
  };

  public func getAnnouncementsByModule(moduleId: Nat): async [Announcement] {
    Array.filter(state.announcements, func(a: Announcement) : Bool {
      a.moduleId == moduleId
    })
  };

  public func viewAnnouncements(): async [Announcement] {
    return state.announcements;
  };

  public func getStudentProgress(studentId: Nat): async ?[StudentProgress] {
    let studentOpt = Array.find(state.students, func(s: Student) : Bool { s.id == studentId });
    switch (studentOpt) {
      case (null) { return null; }; // Student not found
      case (?foundStudent) {
        return ?foundStudent.progress;
      };
    };
  };

  public func updateStudentProgress(studentId: Nat, updatedProgress: [StudentProgress]): async () {
    let updatedStudents = Array.map(state.students, func(s: Student) : Student {
      if (s.id == studentId) {
        return {
          id = s.id;
          name = s.name;
          progress = updatedProgress;
        };
      } else {
        return s;
      }
    });
    state.students := updatedStudents;
  };

  public func addStudent(name: Text): async () {
    // Check if the name is already taken
    if (Array.find(state.users, func(u: User) : Bool { u.name == name }) != null) {
      throw Error.reject("Name already exists");
    };
    let newStudent: Student = {
      id = studentIdCounter;
      name = name;
      progress = [];
    };
    let newUser: User = {
      id = studentIdCounter;
      name = name;
      role = "student";
    };
    state.students := Array.append(state.students, [newStudent]);
    state.users := Array.append(state.users, [newUser]); // Add user to users array
    studentIdCounter += 1;
  };

  public func login(name: Text): async ?Text {
    let userOpt = Array.find(state.users, func(u: User) : Bool { u.name == name });
    switch (userOpt) {
      case (null) { return null; }; // User not found
      case (?user) {
        return ?user.role; // Return the user's role
      };
    };
  };

  public func getTeachers(): async [Teacher] {
    return state.teachers;
  };

  public func getStudents(): async [Student] {
    return state.students;
  };

  public func getLessonsByModule(moduleId: Nat): async [Lesson] {
    let moduleOpt = Array.find(state.modules, func(m: Module) : Bool { m.id == moduleId });
    switch (moduleOpt) {
      case (null) { return []; }; // Module not found
      case (?foundModule) {
        return foundModule.lessons;
      };
    };
  };

  public func submitQuizAnswers(studentId: Nat, moduleId: Nat, lessonId: Nat, quizId: Nat, answers: [Nat]): async () {
    let moduleOpt = Array.find(state.modules, func(m: Module) : Bool { m.id == moduleId });
    switch (moduleOpt) {
      case (null) { return; }; // Module not found
      case (?foundModule) {
        let lessonOpt = Array.find(foundModule.lessons, func(l: Lesson) : Bool { l.id == lessonId });
        switch (lessonOpt) {
          case (null) { return; }; // Lesson not found
          case (?foundLesson) {
            switch (foundLesson.quiz) {
              case (null) { return; }; // Quiz not found
              case (?foundQuiz) {
                if (foundQuiz.id != quizId) { return; }; // Quiz ID mismatch
                // Generate an array of scores (1 or 0) for each question
                let scores = Array.tabulate(foundQuiz.questions.size(), func(i : Nat) : Nat {
                  if (i < answers.size() and answers[i] == foundQuiz.questions[i].correctAnswerIndex) {
                    return 1;
                  } else {
                    return 0;
                  }
                });
                // Use Array.fold to sum up the scores
                let score = Array.foldLeft<Nat, Nat>(scores, 0, func (acc: Nat, val: Nat) : Nat {
                  acc + val
                });

                // Update student progress
                let updatedStudents = Array.map(state.students, func(s: Student) : Student {
                  if (s.id == studentId) {
                    let updatedProgress = Array.map(s.progress, func(p: StudentProgress) : StudentProgress {
                      if (p.moduleId == moduleId and p.lessonId == lessonId) {
                        return {
                          studentId = p.studentId;
                          moduleId = p.moduleId;
                          lessonId = p.lessonId;
                          completed = true;
                          quizScores = Array.append(p.quizScores, [(quizId, score)]);
                        };
                      } else {
                        return p;
                      }
                    });
                    return {
                      id = s.id;
                      name = s.name;
                      progress = updatedProgress;
                    };
                  } else {
                    return s;
                  }
                });
                state.students := updatedStudents;
              };
            };
          };
        };
      };
    };
  };

  public func getStudentIdByName(name: Text): async ?Nat {
    let studentOpt = Array.find(state.students, func(s: Student) : Bool { s.name == name });
    switch (studentOpt) {
      case (null) { return null; }; // Student not found
      case (?foundStudent) {
        return ?foundStudent.id;
      };
    };
  };

  public func getTeacherIdByName(name: Text): async ?Nat {
    let teacherOpt = Array.find(state.teachers, func(t: Teacher) : Bool { t.name == name });
    switch (teacherOpt) {
      case (null) { return null; }; // Teacher not found
      case (?foundTeacher) {
        return ?foundTeacher.id;
      };
    };
  };

  public func uploadFile(bytes: Blob) : async Bool {
      uploadedFile := ?bytes;
      return true;
  };

  // Optional: Function to retrieve the file
  public query func getFile() : async ?Blob {
      return uploadedFile;
  };
};
