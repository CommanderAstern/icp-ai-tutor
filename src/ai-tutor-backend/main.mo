import Array "mo:base/Array";
import Error "mo:base/Error";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Types "Types";
import Cycles "mo:base/ExperimentalCycles";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import List "mo:base/List";
import Text "mo:base/Text";
import Int "mo:base/Int";
import JSON "mo:json.mo";

shared ({ caller = creator }) actor class () {
  type Question = {
    questionText: Text;
    options: [Text];
    correctAnswerIndex: Nat;
  };

  type GeneratedQuestion = {
    question: Text;
    answers: [Text];
    correctAnswerIndex: Nat;
  };

  type User = {
    id: Nat;
    name: Text;
    role: Text; // "student", "teacher", or "none"
  };

  type ChatMessage = {
    sender: Text;
    content: Text;
  };

  type ChatHistory = {
    studentId: Nat;
    moduleId: Nat;
    lessonId: Nat;
    messages: [ChatMessage];
  };

  type Quiz = {
    questions: [Question];
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
    quizScore: ?(Nat, Nat); // (score, totalQuestions)
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
    var chatHistory: [ChatHistory];
  };

  private var state: State = {
    var modules = [];
    var teachers = [];
    var students = [];
    var announcements = [];
    var users = [];
    var chatHistory = [];
  };

  // Counters for generating IDs
  private var moduleIdCounter: Nat = 0;
  private var lessonIdCounter: Nat = 0;
  private var announcementIdCounter: Nat = 0;
  private var teacherIdCounter: Nat = 0;
  private var studentIdCounter: Nat = 0;

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


  public func getModules(): async [Module] {
    return state.modules;
  };

  public func getQuizQuestionsByLesson(moduleId: Nat, lessonId: Nat): async ?([Question], [[Text]]) {
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

  public func getQuizQuestionsByLessonAdmin(moduleId: Nat, lessonId: Nat): async ?([Question], [[Text]], [Nat]) {
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

  public func updateLessonCompletion(studentId: Nat, moduleId: Nat, lessonId: Nat, completed: Bool): async () {
    let studentOpt = Array.find(state.students, func(s: Student) : Bool { s.id == studentId });
    switch (studentOpt) {
      case (null) {
        throw Error.reject("Student not found");
      };
      case (?student) {
        let updatedProgress = Array.map(student.progress, func(p: StudentProgress) : StudentProgress {
          if (p.moduleId == moduleId and p.lessonId == lessonId) {
            {
              studentId = p.studentId;
              moduleId = p.moduleId;
              lessonId = p.lessonId;
              completed = completed;
              quizScore = p.quizScore; // Updated field name
            };
          } else {
            p;
          };
        });

        let updatedStudent: Student = {
          id = student.id;
          name = student.name;
          progress = updatedProgress;
        };

        let updatedStudents = Array.map(state.students, func(s: Student) : Student {
          if (s.id == studentId) {
            updatedStudent;
          } else {
            s;
          };
        });

        state.students := updatedStudents;
      };
    };
  };

  // public func updateQuizProgress(studentId: Nat, moduleId: Nat, lessonId: Nat, quizId: Nat, score: Nat): async () {
  //   let studentOpt = Array.find(state.students, func(s: Student) : Bool { s.id == studentId });
  //   switch (studentOpt) {
  //     case (null) {
  //       throw Error.reject("Student not found");
  //     };
  //     case (?student) {
  //       let updatedProgress = Array.map(student.progress, func(p: StudentProgress) : StudentProgress {
  //         if (p.moduleId == moduleId and p.lessonId == lessonId) {
  //           {
  //             studentId = p.studentId;
  //             moduleId = p.moduleId;
  //             lessonId = p.lessonId;
  //             completed = p.completed;
  //             quizScores = Array.append(p.quizScores, [(quizId, score)]);
  //           };
  //         } else {
  //           p;
  //         };
  //       });

  //       let updatedStudent: Student = {
  //         id = student.id;
  //         name = student.name;
  //         progress = updatedProgress;
  //       };

  //       let updatedStudents = Array.map(state.students, func(s: Student) : Student {
  //         if (s.id == studentId) {
  //           updatedStudent;
  //         } else {
  //           s;
  //         };
  //       });

  //       state.students := updatedStudents;
  //     };
  //   };
  // };

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

  public func submitQuizAnswers(studentId: Nat, moduleId: Nat, lessonId: Nat, answers: [Nat]): async () {
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
                    let progressOpt = Array.find(s.progress, func(p: StudentProgress) : Bool {
                      p.moduleId == moduleId and p.lessonId == lessonId
                    });
                    
                    let updatedProgress = switch (progressOpt) {
                      case (null) {
                        // Create a new progress entry
                        let newProgress: StudentProgress = {
                          studentId = studentId;
                          moduleId = moduleId;
                          lessonId = lessonId;
                          completed = true;
                          quizScore = ?(score, foundQuiz.questions.size());
                        };
                        Array.append(s.progress, [newProgress]);
                      };
                      case (?_) {
                        // Update the existing progress entry
                        Array.map(s.progress, func(p: StudentProgress) : StudentProgress {
                          if (p.moduleId == moduleId and p.lessonId == lessonId) {
                            return {
                              studentId = p.studentId;
                              moduleId = p.moduleId;
                              lessonId = p.lessonId;
                              completed = true;
                              quizScore = ?(score, foundQuiz.questions.size());
                            };
                          } else {
                            return p;
                          }
                        });
                      };
                    };
                    
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

  public func queryServer(queryText : Text, storeIndex : Nat) : async Text {
    //1. DECLARE MANAGEMENT CANISTER
    let ic : Types.IC = actor ("aaaaa-aa");

    //2. SETUP ARGUMENTS FOR HTTP GET request
    let host : Text = "wealthy-duck-coherent.ngrok-free.app";
    let url = "https://" # host # "/query";

    let request_headers = [
      { name = "Host"; value = host # ":443" },
      { name = "Content-Type"; value = "application/json" },
    ];

    let request_body_json: Text = "{\"query\":\"" # queryText # "\",\"store_id\":" # Nat.toText(storeIndex) # "}";
    let request_body_as_Blob: Blob = Text.encodeUtf8(request_body_json);
    let request_body_as_nat8: [Nat8] = Blob.toArray(request_body_as_Blob);

    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : Types.HttpRequestArgs = {
      url = url;
      max_response_bytes = null;
      headers = request_headers;
      body = ?request_body_as_nat8;
      method = #post; // Use POST method for sending JSON data
      transform = ?transform_context;
    };

    //3. ADD CYCLES TO PAY FOR HTTP REQUEST
    Cycles.add(20_949_972_000);

    //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

    //5. DECODE THE RESPONSE
    let response_body: Blob = Blob.fromArray(http_response.body);
    let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?result) { result };
    };

    //6. RETURN RESPONSE OF THE BODY
    decoded_text
  };

  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
  let transformed : Types.CanisterHttpResponsePayload = {
    status = raw.response.status;
    body = raw.response.body;
    headers = raw.response.headers;
  };
  transformed;
  };

  public func generateQuestion(moduleId: Nat, lessonId: Nat, queryText: Text, storeIndex: Nat): async () {
    //1. DECLARE MANAGEMENT CANISTER
    let ic : Types.IC = actor ("aaaaa-aa");

    //2. SETUP ARGUMENTS FOR HTTP GET request
    let host : Text = "wealthy-duck-coherent.ngrok-free.app";
    let url = "https://" # host # "/generate_question";

    let request_headers = [
      { name = "Host"; value = host # ":443" },
      { name = "Content-Type"; value = "application/json" },
    ];

    let request_body_json: Text = "{\"query\":\"" # queryText # "\",\"store_id\":" # Nat.toText(storeIndex) # "}";
    let request_body_as_Blob: Blob = Text.encodeUtf8(request_body_json);
    let request_body_as_nat8: [Nat8] = Blob.toArray(request_body_as_Blob);

    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : Types.HttpRequestArgs = {
      url = url;
      max_response_bytes = null;
      headers = request_headers;
      body = ?request_body_as_nat8;
      method = #post; // Use POST method for sending JSON data
      transform = ?transform_context;
    };

    //3. ADD CYCLES TO PAY FOR HTTP REQUEST
    Cycles.add(20_949_972_000);

    //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

    //5. DECODE THE RESPONSE
    let response_body: Blob = Blob.fromArray(http_response.body);
    let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?result) { result };
    };

    // Parse the decoded JSON response into Question type
    let generatedQuestions: [Question] = parseGeneratedQuestions(decoded_text);

    // Store the generated questions in the specified module and lesson
    let updatedModules = Array.map(state.modules, func(m: Module): Module {
      if (m.id == moduleId) {
        let updatedLessons = Array.map(m.lessons, func(l: Lesson): Lesson {
          if (l.id == lessonId) {
            let updatedQuiz = switch (l.quiz) {
              case (null) {
                ?{
                  questions = generatedQuestions;
                  id = 0; // Assign a default quiz ID of 0
                };
              };
              case (?quiz) {
                ?{
                  questions = Array.append(quiz.questions, generatedQuestions);
                };
              };
            };
            {
              id = l.id;
              title = l.title;
              content = l.content;
              quiz = updatedQuiz;
            };
          } else {
            l;
          }
        });
        {
          id = m.id;
          title = m.title;
          lessons = updatedLessons;
          teacherId = m.teacherId;
          teacherName = m.teacherName;
        };
      } else {
        m;
      }
    });
    state.modules := updatedModules;
  };

  private func parseGeneratedQuestions(jsonText: Text): [Question] {
    switch (JSON.parse(jsonText)) {
      case (null) {
        // Parsing failed
        return [];
      };
      case (? json) {
        switch (json) {
          case (#Array(questions)) {
            let generatedQuestions = Array.map(questions, func (q: JSON.JSON) : Question {
              switch (q) {
                case (#Object(fields)) {
                  let question = getTextField(fields, "question");
                  let answers = getArrayField(fields, "answers");
                  let correctAnswerIndex = getNatField(fields, "correct_index");
                  {
                    questionText = question;
                    options = answers;
                    correctAnswerIndex = correctAnswerIndex;
                  };
                };
                case (_) {
                  // Invalid question format
                  {
                    questionText = "";
                    options = ["Placeholder", "Placeholder","Placeholder","Placeholder"];
                    correctAnswerIndex = 0;
                  };
                };
              };
            });
            generatedQuestions;
          };
          case (_) {
            // Invalid JSON format
            return [];
          };
        };
      };
    };
  };

  private func getTextField(fields: [(Text, JSON.JSON)], fieldName: Text) : Text {
    switch (List.find(List.fromArray(fields), func ((name, _): (Text, JSON.JSON)) : Bool { name == fieldName })) {
      case (null) { "" };
      case (? (_, #String(value))) { value };
      case (_) { "" };
    };
  };

  private func getArrayField(fields: [(Text, JSON.JSON)], fieldName: Text) : [Text] {
    switch (List.find(List.fromArray(fields), func ((name, _): (Text, JSON.JSON)) : Bool { name == fieldName })) {
      case (null) { [] };
      case (? (_, #Array(values))) {
        Array.map(values, func (v: JSON.JSON) : Text {
          switch (v) {
            case (#String(value)) { value };
            case (_) { "" };
          };
        });
      };
      case (_) { [] };
    };
  };

  private func getNatField(fields: [(Text, JSON.JSON)], fieldName: Text) : Nat {
    switch (List.find(List.fromArray(fields), func ((name, _): (Text, JSON.JSON)) : Bool { name == fieldName })) {
      case (null) { 0 };
      case (? (_, #Number(value))) { Int.abs(value) };
      case (_) { 0 };
    };
  };

  public func askQuestion(studentId: Nat, moduleId: Nat, lessonId: Nat, queryText: Text): async Text {
    let response = await queryServer(queryText, 0);

    // Store the chat history
    let chatMessage: ChatMessage = {
      sender = "Student";
      content = queryText;
    };
    let assistantMessage: ChatMessage = {
      sender = "Assistant";
      content = response;
    };

    let updatedChatHistory = Array.map(state.chatHistory, func(ch: ChatHistory): ChatHistory {
      if (ch.studentId == studentId and ch.moduleId == moduleId and ch.lessonId == lessonId) {
        {
          studentId = ch.studentId;
          moduleId = ch.moduleId;
          lessonId = ch.lessonId;
          messages = Array.append(ch.messages, [chatMessage, assistantMessage]);
        };
      } else {
        ch;
      }
    });

    if (Array.find(updatedChatHistory, func(ch: ChatHistory): Bool {
      ch.studentId == studentId and ch.moduleId == moduleId and ch.lessonId == lessonId
    }) == null) {
      let newChatHistory: ChatHistory = {
        studentId = studentId;
        moduleId = moduleId;
        lessonId = lessonId;
        messages = [chatMessage, assistantMessage];
      };
      state.chatHistory := Array.append(state.chatHistory, [newChatHistory]);
    } else {
      state.chatHistory := updatedChatHistory;
    };

    response;
  };

  public func getChatHistory(studentId: Nat, moduleId: Nat, lessonId: Nat): async ?[ChatMessage] {
    let chatHistoryOpt = Array.find(state.chatHistory, func(ch: ChatHistory): Bool {
      ch.studentId == studentId and ch.moduleId == moduleId and ch.lessonId == lessonId
    });

    switch (chatHistoryOpt) {
      case (null) {
        return null;
      };
      case (?chatHistory) {
        return ?chatHistory.messages;
      };
    };
  };
};
