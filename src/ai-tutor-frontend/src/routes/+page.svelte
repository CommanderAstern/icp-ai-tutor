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

<main class="bg-gray-100 min-h-screen">
  <div class="container mx-auto px-4 py-8"> 
  <img src="/logo2.svg" alt="DFINITY logo" class="w-40 mx-auto mb-8" />

  {#if role === "" || role === undefined || role[0] === ""}
    <div class="max-w-md mx-auto mt-8">
      <form action="#" on:submit|preventDefault={onSubmit} class="bg-white shadow-md rounded px-8 pt-6 pb-8 mb-4">
        <div class="mb-4">
          <label for="name" class="block text-gray-700 font-bold mb-2">Enter your name: &nbsp;</label>
          <input id="name" alt="Name" type="text" class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />
        </div>
        <div class="flex items-center justify-between">
          <button type="submit" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">Login</button>
        </div>
      </form>
    </div>
  {:else}
  <section id="greeting" class="mt-8">
    <h2 class="text-2xl font-bold mb-4">{message}</h2>
    <!-- Teacher Dashboard -->
    {#if role[0] === "teacher"}
      <div class="flex">
        <div class="w-1/4 bg-white shadow-md rounded p-4 mr-4">
          <h3 class="text-xl font-bold mb-4">Teacher Dashboard</h3>
          <h4 class="text-lg font-bold mb-2">Create Module</h4>
          <input type="text" placeholder="Module Title" bind:value={newModuleTitle} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
          <button on:click={createModule} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline mb-4">Create Module</button>

          <h4 class="text-lg font-bold mb-2">Create Lesson</h4>
          <select bind:value={selectedModuleId} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2">
            <option value={null}>Select Module</option>
            {#each modules as module}
              <option value={module.id}>{module.title}</option>
            {/each}
          </select>
          <input type="text" placeholder="Lesson Title" bind:value={newLessonTitle} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
          <textarea placeholder="Lesson Content" bind:value={newLessonContent} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2"></textarea>
          <button on:click={createLesson} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline mb-4">Create Lesson</button>

          <h4 class="text-lg font-bold mb-2">Create Announcement</h4>
          <select bind:value={selectedModuleId} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2">
            <option value={null}>Select Module</option>
            {#each modules as module}
              <option value={module.id}>{module.title}</option>
            {/each}
          </select>
          <input type="text" placeholder="Announcement Content" bind:value={newAnnouncementContent} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
          <input type="text" placeholder="Announcement Date" bind:value={newAnnouncementDate} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
          <button on:click={createAnnouncement} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline mb-4">Create Announcement</button>

          <h4 class="text-lg font-bold mb-2">Create Student</h4>
          <input type="text" placeholder="Student Name" bind:value={newStudentName} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
          <button on:click={createStudent} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">Create Student</button>
        </div>
        <div class="w-3/4">
          <h4 class="text-lg font-bold mb-4">Student Progress</h4>
          <table class="w-full text-left table-collapse">
            <thead>
              <tr>
                <th class="text-sm font-medium text-gray-700 p-2 bg-gray-100">Student</th>
                <th class="text-sm font-medium text-gray-700 p-2 bg-gray-100">Progress</th>
              </tr>
            </thead>
            <tbody>
              {#await backend.getStudents() then studentsData}
                {#each studentsData as studentData}
                  {@const student = studentData}
                  <tr class="hover:bg-gray-100">
                    <td class="p-2 border-t border-gray-300">{student.name}</td>
                    <td class="p-2 border-t border-gray-300">
                      <button on:click={() => toggleStudentDetails(student.id)} class="text-blue-500 hover:text-blue-700">
                        {expandedStudentId === student.id ? 'Hide Details' : 'Show Details'}
                      </button>
                    </td>
                  </tr>
                  {#if expandedStudentId === student.id}
                    <tr>
                      <td colspan="2" class="p-0">
                        <table class="w-full text-left table-collapse">
                          <thead>
                            <tr>
                              <th class="text-sm font-medium text-gray-700 p-2 bg-gray-100">Module</th>
                              <th class="text-sm font-medium text-gray-700 p-2 bg-gray-100">Lesson</th>
                              <th class="text-sm font-medium text-gray-700 p-2 bg-gray-100">Completed</th>
                              <th class="text-sm font-medium text-gray-700 p-2 bg-gray-100">Quiz Score</th>
                            </tr>
                          </thead>
                          <tbody>
                            {#each modules as module}
                              {@const moduleProgress = getModuleProgress(student.progress, module.id)}
                              {#if moduleProgress.length > 0}
                                {#each module.lessons as lesson}
                                  {@const lessonProgress = getLessonProgress(moduleProgress, lesson.id)}
                                  <tr class="hover:bg-gray-100">
                                    <td class="p-2 border-t border-gray-300">{module.title}</td>
                                    <td class="p-2 border-t border-gray-300">{lesson.title}</td>
                                    <td class="p-2 border-t border-gray-300">{lessonProgress ? (lessonProgress.completed ? 'Yes' : 'No') : 'No'}</td>
                                    <td class="p-2 border-t border-gray-300">
                                      {#if lessonProgress && lessonProgress.quizScore}
                                        {`${Number(lessonProgress.quizScore[0][0])} / ${Number(lessonProgress.quizScore[0][1])}`}
                                      {:else}
                                        N/A
                                      {/if}
                                    </td>
                                  </tr>
                                {/each}
                              {:else}
                                <tr class="hover:bg-gray-100">
                                  <td class="p-2 border-t border-gray-300">{module.title}</td>
                                  <td colspan="3" class="p-2 border-t border-gray-300">No progress in this module</td>
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
        </div>
      </div>
    {:else if role[0] === "student"}
      <div class="flex">
        <div class="w-1/4 bg-white shadow-md rounded p-4 mr-4">
          <h3 class="text-xl font-bold mb-4">Student Dashboard</h3>
          <h4 class="text-lg font-bold mb-2">Modules</h4>
          {#each modules as module}
            <div class="mb-4">
              <h5 class="text-lg font-bold mb-2">{module.title}</h5>
              {#await calculateStudentProgress() then progress}
                {#if progress}
                  {#each progress as p}
                    {#if p.moduleId === module.id}
                      <p class="text-gray-700">Progress: {p.progressIndicator}</p>
                      <p class="text-gray-700">Average Quiz Score: {p.averageScorePercent}%</p>
                    {/if}
                  {/each}
                {/if}
              {/await}

              <p class="text-gray-700">Teacher: {module.teacherName}</p>
              <h6 class="text-lg font-bold mt-4 mb-2">Announcements</h6>
              {#await getModuleAnnouncements(module.id) then announcements}
                {#each announcements as announcement}
                  <p class="text-gray-700">{announcement.content} - {announcement.date}</p>
                {/each}
              {/await}
              <h6 class="text-lg font-bold mt-4 mb-2">Lessons</h6>
              {#await backend.getLessonsByModule(module.id) then lessons}
                {#each lessons as lesson}
                  <div class="mb-2">
                    <h7 class="text-base font-bold">{lesson.title}</h7>
                    <button on:click={() => selectLesson(module.id, lesson.id)} class="text-blue-500 hover:text-blue-700">View Lesson</button>
                  </div>
                {/each}
              {/await}
            </div>
          {/each}
        </div>
        <div class="w-3/4">
          <!-- Lesson View -->
          {#if selectedLesson}
            <div class="lesson-view bg-white shadow-md rounded p-4">
              <h4 class="text-xl font-bold mb-4">{selectedLesson.title}</h4>
              <p class="text-gray-700 mb-4">{selectedLesson.content}</p>

              <!-- Quiz Section -->
              <div class="quiz-section mb-8">
                <h5 class="text-lg font-bold mb-2">Quiz</h5>
                <div class="question-generation mb-4">
                  <input type="text" placeholder="Enter a query to generate questions" bind:value={questionQuery} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
                  <button on:click={generateQuestions} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">Generate Questions</button>
                </div>
                {#await getQuizQuestions(selectedLesson.id) then questions}
                  {#if questions.length > 0}
                    {#each questions as question}
                      <p class="text-gray-700 mb-2">{question.id}. {question.questionText}</p>
                      {#each question.options as option, optionIndex}
                        <label class="inline-flex items-center mb-2">
                          <input type="radio" name="question{question.id}" value={optionIndex} bind:group={selectedAnswers[question.id - 1]} class="form-radio h-5 w-5 text-blue-600">
                          <span class="ml-2 text-gray-700">{option}</span>
                        </label>
                      {/each}
                    {/each}
                    <button on:click={submitQuiz} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">Submit Quiz</button>
                  {:else}
                    <p class="text-gray-700">No questions available.</p>
                  {/if}
                {/await}
              </div>

              <!-- Chat Section -->
              <div class="chat-section mb-8">
                <h5 class="text-lg font-bold mb-2">Chat with AI</h5>
                <div class="chat-history mb-4">
                  {#each chatHistory as message}
                    <p class="mb-2 {message.sender === 'Student' ? 'text-right text-blue-500' : 'text-left text-gray-700'}">{message.content}</p>
                  {/each}
                </div>
                <input type="text" placeholder="Ask a question" bind:value={newQuestion} class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline mb-2" />
                <button on:click={sendQuestion} class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">Send</button>
              </div>

              <!-- Progress Tracking -->
              <div class="progress-section">
                <h5 class="text-lg font-bold mb-2">Progress</h5>
                <label class="inline-flex items-center">
                  <input type="checkbox" bind:checked={lessonCompleted} on:change={updateLessonCompletion} class="form-checkbox h-5 w-5 text-blue-600">
                  <span class="ml-2 text-gray-700">Mark as Completed</span>
                </label>
              </div>
            </div>
          {/if}
          </div>
          </div>
        {/if}
        <button on:click={() => { name = ""; role = ""; message = ""; }} class="bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline mt-8">Logout</button>
      </section>
  {/if}
</div> </main>