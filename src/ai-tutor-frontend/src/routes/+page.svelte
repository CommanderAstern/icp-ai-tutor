<script>
  import "../index.scss";
  import { backend } from "$lib/canisters";
  import { AssetManager } from "@dfinity/assets";

  let name = "";
  let role = "";
  let message = "";
  let modules = [];
  let announcements = [];
  let newAnnouncementContent = "";
  let newAnnouncementDate = "";
  let newModuleTitle = "";
  let newLessonTitle = "";
  let newLessonContent = "";
  let newStudentName = "";
  let teacherId = null;
  let studentId = null;
  let fileToUpload = null;
  let selectedLesson = null;
  let selectedAnswers = [];
  let chatHistory = [];
  let newQuestion = "";
  let lessonCompleted = false;
  let selectedModuleId = null;
  let selectedLessonId = null;
  let questionQuery = "";

  async function generateQuestions() {
    if (questionQuery.trim() !== "") {
      await backend.generateQuestion(selectedModuleId, selectedLessonId, questionQuery, 0);
      // Refresh the quiz questions after generating new ones
      await getQuizQuestions(selectedLesson.id);
      questionQuery = "";
    }
  }

  async function updateLessonCompletion() {
    await backend.updateLessonCompletion(studentId, selectedModuleId, selectedLessonId, lessonCompleted);
  }

  function selectLesson(moduleId, lessonId) {
    selectedModuleId = Number(moduleId);
    selectedLessonId = Number(lessonId);
    selectedLesson = modules.find(m => m.id === moduleId).lessons.find(l => l.id === lessonId);
    selectedAnswers = Array(selectedLesson.quiz.questions.length).fill(null);
    getChatHistory();
    checkLessonCompleted();
  }

  async function getQuizQuestions(lessonId) {
    return await backend.getQuizQuestionsByLesson(selectedModuleId, lessonId, selectedLesson.quiz.id);
  }

  async function submitQuiz() {
    await backend.submitQuizAnswers(studentId, selectedModuleId, selectedLessonId, selectedLesson.quiz.id, selectedAnswers);
    // Display a success message or update the UI
  }

  async function sendQuestion() {
    if (newQuestion.trim() !== "") {
      const response = await backend.askQuestion(studentId, selectedModuleId, selectedLessonId, newQuestion);
      chatHistory = [...chatHistory, { sender: "Student", content: newQuestion }, { sender: "Assistant", content: response }];
      newQuestion = "";
    }
  }

  async function getChatHistory() {
    const history = await backend.getChatHistory(studentId, selectedModuleId, selectedLessonId);
    chatHistory = history || [];
  }

  async function checkLessonCompleted() {
    const progress = await backend.getStudentProgress(studentId);
    const lessonProgress = progress.find(p => p.moduleId === selectedModuleId && p.lessonId === selectedLessonId);
    lessonCompleted = lessonProgress ? lessonProgress.completed : false;
  }

  async function onSubmit(event) {
    const enteredName = event.target.name.value;
    const response = await backend.login(enteredName);
    if (response) {
      name = enteredName;
      role = response;
      message = `Welcome, ${name}! You are logged in as a ${role}.`;
      await loadData();
    } else {
      name = "";
      role = "";
      message = "Error: User not found.";
    }
    console.log(name, role, message);
    return false;
  }

  async function loadData() {
    modules = await backend.getModules();
    announcements = await backend.viewAnnouncements();
    if (role[0] === "teacher") {
      teacherId = Number(await backend.getTeacherIdByName(name));
    } else if (role[0] === "student") {
      studentId = Number(await backend.getStudentIdByName(name));
    }
  }

  async function createAnnouncement() {
    if (selectedModuleId !== null) {
      await backend.addAnnouncement(newAnnouncementContent, newAnnouncementDate, selectedModuleId);
      newAnnouncementContent = "";
      newAnnouncementDate = "";
      selectedModuleId = null;
      await loadData();
    }
  }

  async function createModule() {
    if (teacherId !== null) {
      await backend.addModule(teacherId, newModuleTitle, []);
      newModuleTitle = "";
      await loadData();
    }
  }

  async function createLesson() {
    if (selectedModuleId !== null && teacherId !== null) {
      await backend.addLesson(teacherId, selectedModuleId, newLessonTitle, newLessonContent, []);
      newLessonTitle = "";
      newLessonContent = "";
      selectedModuleId = null;
      await loadData();
    }
  }


  async function createStudent() {
    await backend.addStudent(newStudentName);
    newStudentName = "";
    await loadData();
  }

  async function getModuleAnnouncements(moduleId) {
    return await backend.getAnnouncementsByModule(moduleId);
  }
</script>

<main>
  <img src="/logo2.svg" alt="DFINITY logo" />
  <br />
  <br />

  {#if role === "" || role === undefined || role[0] === ""}
    <form action="#" on:submit|preventDefault={onSubmit}>
      <label for="name">Enter your name: &nbsp;</label>
      <input id="name" alt="Name" type="text" />
      <button type="submit">Login</button>
    </form>
  {:else}
    <section id="greeting">
      <h2>{message}</h2>
      {#if role[0] === "teacher"}
        <h3>Teacher Dashboard</h3>
        <h4>Create Module</h4>
        <input type="text" placeholder="Module Title" bind:value={newModuleTitle} />
        <button on:click={createModule}>Create Module</button>

        <h4>Create Lesson</h4>
        <select bind:value={selectedModuleId}>
          <option value={null}>Select Module</option>
          {#each modules as module}
            <option value={module.id}>{module.title}</option>
          {/each}
        </select>
        <input type="text" placeholder="Lesson Title" bind:value={newLessonTitle} />
        <textarea placeholder="Lesson Content" bind:value={newLessonContent}></textarea>
        <button on:click={createLesson}>Create Lesson</button>

        <h4>Create Announcement</h4>
        <select bind:value={selectedModuleId}>
          <option value={null}>Select Module</option>
          {#each modules as module}
            <option value={module.id}>{module.title}</option>
          {/each}
        </select>
        <input type="text" placeholder="Announcement Content" bind:value={newAnnouncementContent} />
        <input type="text" placeholder="Announcement Date" bind:value={newAnnouncementDate} />
        <button on:click={createAnnouncement}>Create Announcement</button>

        <h4>Create Student</h4>
        <input type="text" placeholder="Student Name" bind:value={newStudentName} />
        <button on:click={createStudent}>Create Student</button>
      {:else if role[0] === "student"}
        <h3>Student Dashboard</h3>
        <h4>Modules</h4>
        {#each modules as module}
          <div>
            <h5>{module.title}</h5>
            <p>Teacher: {module.teacherName}</p>
            <h6>Announcements</h6>
            {#await getModuleAnnouncements(module.id) then announcements}
              {#each announcements as announcement}
                <p>{announcement.content} - {announcement.date}</p>
              {/each}
            {/await}
            <h6>Lessons</h6>
            {#await backend.getLessonsByModule(module.id) then lessons}
              {#each lessons as lesson}
                <div>
                  <h7>{lesson.title}</h7>
                  <button on:click={() => selectLesson(module.id, lesson.id)}>View Lesson</button>
                </div>
              {/each}
            {/await}
          </div>
        {/each}
        <!-- Lesson View -->
        {#if selectedLesson}
          <div class="lesson-view">
            <h4>{selectedLesson.title}</h4>
            <p>{selectedLesson.content}</p>
            
            <!-- Quiz Section -->
            <div class="quiz-section">
              <h5>Quiz</h5>
              <div class="question-generation">
                <input type="text" placeholder="Enter a query to generate questions" bind:value={questionQuery} />
                <button on:click={generateQuestions}>Generate Questions</button>
              </div>
              {#await getQuizQuestions(selectedLesson.id) then questions}
                {#each questions as question, index}
                  <p>{index + 1}. {question.questionText}</p>
                  {#each question.options as option, optionIndex}
                    <label>
                      <input type="radio" name="question{index}" value={optionIndex} bind:group={selectedAnswers[index]}>
                      {option}
                    </label>
                  {/each}
                {/each}
                <button on:click={submitQuiz}>Submit Quiz</button>
              {/await}
            </div>
            
            <!-- Chat Section -->
            <div class="chat-section">
              <h5>Chat with AI</h5>
              <div class="chat-history">
                {#each chatHistory as message}
                  <p class="{message.sender === 'Student' ? 'student-message' : 'assistant-message'}">{message.content}</p>
                {/each}
              </div>
              <input type="text" placeholder="Ask a question" bind:value={newQuestion} />
              <button on:click={sendQuestion}>Send</button>
            </div>
            
            <!-- Progress Tracking -->
            <div class="progress-section">
              <h5>Progress</h5>
              <label>
                <input type="checkbox" bind:checked={lessonCompleted} on:change={updateLessonCompletion}>
                Mark as Completed
              </label>
            </div>
          </div>
        {/if}
      {/if}
      <button on:click={() => { name = ""; role = ""; message = ""; }}>Logout</button>
    </section>
  {/if}
</main>