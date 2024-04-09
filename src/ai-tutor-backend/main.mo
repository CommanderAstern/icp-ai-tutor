import Array "mo:base/Array";
import Error "mo:base/Error";
import Bool "mo:base/Bool";


actor {
  type Question = {
    questionText: Text;
    options: [Text];
    correctAnswerIndex: Nat;
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
  };

  type StudentProgress = {
    studentId: Text;
    moduleId: Nat;
    lessonId: Nat;
    completed: Bool;
    quizScores: [(Nat, Nat)]; // (QuizID, Score)
  };

  type Teacher = {
    id: Text;
    name: Text;
    modules: [Nat];
  };

  type Student = {
    id: Text;
    name: Text;
    progress: [StudentProgress];
  };

  type Announcement = {
    content: Text;
    date: Text;
  };

  type State = {
    var modules: [Module];
    var teachers: [Teacher];
    var students: [Student];
    var announcements: [Announcement];
  };

  private var state: State = {
    var modules = [];
    var teachers = [];
    var students = [];
    var announcements = [];
  };

  public func addModule(teacherId: Text, newModule: Module): async () {
    // Assuming a simple access control check (to be replaced with real logic)
    if (Array.find(state.teachers, func(t: Teacher) : Bool { t.id == teacherId }) != null) {
      state.modules := Array.append(state.modules, [newModule]);
    } else {
      // Teacher not found, handle the error case
      // You can choose to throw an error, log a message, or take any other appropriate action
      throw Error.reject("Teacher not found");
    }
  };
  
  public func addLesson(teacherId: Text, moduleId: Nat, newLesson: Lesson): async () {
    // Check teacher exists
    if (Array.find(state.teachers, func(t: Teacher) : Bool { t.id == teacherId }) != null) {
      // Find module by ID and add the lesson, correctly using Array.map
      let updatedModules = Array.map(state.modules, func(m: Module) : Module {
        if (m.id == moduleId) {
          // If the module is the one we're looking for, return a new module with the new lesson added
          return {
            id = m.id;
            title = m.title;
            lessons = Array.append(m.lessons, [newLesson]);
          };
        } else {
          // Otherwise, return the module unchanged
          return m;
        }
      });
      // Mutate the state with the updated modules array
      state.modules := updatedModules;
    } else {
      // Teacher not found, handle the error case
      throw Error.reject("Teacher not found");
    }
  };




  public func setQuiz(teacherId: Text, moduleId: Nat, lessonId: Nat, newQuiz: Quiz): async () {
    // Initialize a flag to indicate whether the quiz was successfully set
    var quizSet: Bool = false;

    // Use Array.map to update modules
    let updatedModules: [Module] = Array.map(state.modules, func (m: Module) : Module {
      if (m.id == moduleId) {
        // Found the target module, now update its lessons to include the newQuiz where lessonId matches
        let updatedLessons: [Lesson] = Array.map(m.lessons, func (l: Lesson) : Lesson {
          if (l.id == lessonId) {
            quizSet := true; // Mark that we have set the quiz
            return {
              id = l.id;
              title = l.title;
              content = l.content;
              quiz = ?newQuiz; // Set the newQuiz here, assuming quiz is an optional field in Lesson
            };
          } else {
            return l; // Return the lesson unchanged if not the target
          }
        });
        return {
          id = m.id;
          title = m.title;
          lessons = updatedLessons;
        };
      } else {
        return m; // Return the module unchanged if not the target
      }
    });

    // Update the state with the modified list of modules
    state.modules := updatedModules;

    if (not quizSet) {
      // Quiz not successfully set, handle the error case
      throw Error.reject("Quiz not set");
    }
  };




  public func viewModule(studentId: Text, moduleId: Nat): async ?Module {
    // Explicitly annotate the type of `m` in the lambda function for Array.find
    let moduleOpt = Array.find(state.modules, func(m: Module) : Bool { m.id == moduleId });
    return moduleOpt;
  };


  public func submitQuizAnswers(studentId: Text, moduleId: Nat, lessonId: Nat, quizId: Nat, answers: [Nat]): async Nat {
    let moduleOpt = Array.find(state.modules, func(m: Module) : Bool { m.id == moduleId });
    switch (moduleOpt) {
      case (null) { return 0; }; // Module not found
      case (?foundModule) {
        let lessonOpt = Array.find(foundModule.lessons, func(l: Lesson) : Bool { l.id == lessonId });
        switch (lessonOpt) {
          case (null) { return 0; }; // Lesson not found
          case (?foundLesson) {
            switch (foundLesson.quiz) {
              case (null) { return 0; }; // Quiz not found
              case (?foundQuiz) {
                if (foundQuiz.id != quizId) { return 0; }; // Quiz ID mismatch
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
                return score;
              };
            };
          };
        };
      };
    };
  };

};
