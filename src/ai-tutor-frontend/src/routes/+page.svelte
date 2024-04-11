<script>
  import "../index.scss";
  import { backend } from "$lib/canisters";
  import { AssetManager } from "@dfinity/assets";
  import "../app.css";
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
  let expandedStudentId = null;

  function toggleStudentDetails(studentId) {
    expandedStudentId = expandedStudentId === studentId ? null : studentId;
  }

  async function generateQuestions() {
    if (questionQuery.trim() !== "") {
      await backend.generateQuestion(selectedModuleId, selectedLessonId, questionQuery, 0);
      // Refresh the quiz questions after generating new ones
      await getQuizQuestions(selectedLesson.id);
      getQuizQuestions(selectedLesson.id);
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
    const res = await backend.getQuizQuestionsByLesson(selectedModuleId, lessonId);
    console.log('Quiz questions response:', res);
    // Check if the response is an array and has at least one element
    if (Array.isArray(res) && res.length > 0) {
      // Assuming the response is an array of question objects
      const questions = res[0][0].map((questionObject, index) => ({
        id: index + 1,
        questionText: questionObject.questionText || 'Question text not available',
        options: questionObject.options || [],
      }));

      console.log('Quiz questions:', questions);
      return questions;
    } else {
      console.log('Invalid response format:', res);
      return [];
    }
  }

  async function submitQuiz() {
    console.log('Submitting quiz answers:', selectedAnswers, studentId, selectedModuleId, selectedLessonId);
    await backend.submitQuizAnswers(studentId, selectedModuleId, selectedLessonId, selectedAnswers);
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
    console.log(await backend.getStudents())
    if (role[0] === "teacher") {
      teacherId = Number(await backend.getTeacherIdByName(name));
    } else if (role[0] === "student") {
      studentId = Number(await backend.getStudentIdByName(name));
    }
  }

  function getProgressInModule(progress, moduleId) {
    console.log('Progress:', progress, moduleId);
    for (let i = 0; i < progress.length; i++) {
      if (progress[i].moduleId == moduleId) {
        console.log('Progress in module:', progress[i]);
        return progress[i];
      }
    }
    return null;
  }

  function getModuleProgress(progress, moduleId) {
    return progress.filter(p => p.moduleId == moduleId);
  }

  function getLessonProgress(moduleProgress, lessonId) {
    return moduleProgress.find(p => p.lessonId == lessonId);
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

  async function getProgress() {
    await loadData();
    console.log('Getting progress for student:', studentId);
    let res = await backend.getStudentProgress(studentId);
    console.log('Progress response:', res);
    console.log('Module', modules);
    console.log('Students', await backend.getStudents());
    return res;
  }

  async function calculateStudentProgress() {
    await loadData();
    let studentProgress = await backend.getStudentProgress(studentId);
    console.log('Student progress:', studentProgress);
    console.log('Modules:', modules);
    return modules.map(module => {
    const totalLessons = module.lessons.length;
    let completedLessons = 0;
    let totalScore = 0;
    let obtainedScore = 0;

    studentProgress.forEach(progress => {
      progress = progress;
      console.log('Progress:', progress[0].moduleId, module.id, progress[0].completed, progress[0].quizScore);
      if (progress[0].moduleId == module.id) {
        if (progress[0].completed) {
          completedLessons += 1;
          if (progress[0].quizScore && progress[0].quizScore.length > 0) {
            obtainedScore += Number(progress[0].quizScore[0][0]); // First element of first pair is obtained score
            totalScore += Number(progress[0].quizScore[0][1]); // Second element of first pair is total score
          }
        }
      }
    });

    const progressIndicator = `${completedLessons}/${totalLessons}`;
    // Avoid division by zero
    const averageScorePercent = totalScore > 0 ? ((obtainedScore / totalScore) * 100).toFixed(2) : "N/A";

    return {
      moduleId: module.id,
      progressIndicator,
      averageScorePercent
    };
  });
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
    <button class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-700 transition duration-300">
      Test Tailwind Button
  </button>

  {#if role === "" || role === undefined || role[0] === ""}
    <form action="#" on:submit|preventDefault={onSubmit}>
      <label for="name">Enter your name: &nbsp;</label>
      <input id="name" alt="Name" type="text" />
      <button type="submit">Login</button>
    </form>
  {:else}
    <section id="greeting">
      <h2>{message}</h2>
      <!-- Teacher Dashboard -->
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
        <h4>Student Progress</h4>
        <table>
          <thead>
            <tr>
              <th>Student</th>
              <th>Progress</th>
            </tr>
          </thead>
          <tbody>
            {#await backend.getStudents() then studentsData}
              {#each studentsData as studentData}
                {@const student = studentData}
                <tr>
                  <td>{student.name}</td>
                  <td>
                    <button on:click={() => toggleStudentDetails(student.id)}>
                      {expandedStudentId === student.id ? 'Hide Details' : 'Show Details'}
                    </button>
                  </td>
                </tr>
                {#if expandedStudentId === student.id}
                  <tr>
                    <td colspan="2">
                      <table>
                        <thead>
                          <tr>
                            <th>Module</th>
                            <th>Lesson</th>
                            <th>Completed</th>
                            <th>Quiz Score</th>
                          </tr>
                        </thead>
                        <tbody>
                          {#each modules as module}
                            {@const moduleProgress = getModuleProgress(student.progress, module.id)}
                            {#if moduleProgress.length > 0}
                              {#each module.lessons as lesson}
                                {@const lessonProgress = getLessonProgress(moduleProgress, lesson.id)}
                                <tr>
                                  <td>{module.title}</td>
                                  <td>{lesson.title}</td>
                                  <td>{lessonProgress ? (lessonProgress.completed ? 'Yes' : 'No') : 'No'}</td>
                                  <td>
                                    {#if lessonProgress && lessonProgress.quizScore}
                                      {`${Number(lessonProgress.quizScore[0][0])} / ${Number(lessonProgress.quizScore[0][1])}`}
                                    {:else}
                                      N/A
                                    {/if}
                                  </td>
                                </tr>
                              {/each}
                            {:else}
                              <tr>
                                <td>{module.title}</td>
                                <td colspan="3">No progress in this module</td>
                              </tr>
                            {/if}
                          {/each}
                        </tbody>
                      </table>
                    </td>
                  </tr>
                {/if}
              {/each}
            {/await}
          </tbody>
        </table>
      {:else if role[0] === "student"}
        <h3>Student Dashboard</h3>
        <h4>Modules</h4>
        {#each modules as module}
          <div>
            <h5>{module.title}</h5>
            {#await calculateStudentProgress() then progress}
              {#if progress}
                {#each progress as p}
                  {#if p.moduleId === module.id}
                    <p>Progress: {p.progressIndicator}</p>
                    <p>Average Quiz Score: {p.averageScorePercent}%</p>
                  {/if}
                {/each}
              {/if}
            {/await}

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
                {#if questions.length > 0}
                  {#each questions as question}
                    <p>{question.id}. {question.questionText}</p>
                    {#each question.options as option, optionIndex}
                      <label>
                        <input type="radio" name="question{question.id}" value={optionIndex} bind:group={selectedAnswers[question.id - 1]}>
                        {option}
                      </label>
                    {/each}
                  {/each}
                  <button on:click={submitQuiz}>Submit Quiz</button>
                {:else}
                  <p>No questions available.</p>
                {/if}
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