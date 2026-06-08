<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ClipboardCheck, Send } from 'lucide-vue-next'

import { examApi } from '../api/modules'
import EmptyState from '../components/EmptyState.vue'
import MessageBar from '../components/MessageBar.vue'
import { subjects } from '../constants/options'

const studentName = ref('')
const subject = ref('科目一')
const questions = ref([])
const answers = reactive({})
const result = ref(null)
const loading = ref(false)
const submitting = ref(false)
const message = reactive({ text: '', type: 'info' })

const canSubmit = computed(() => {
  return studentName.value.trim() && questions.value.length && questions.value.every((q) => answers[q.id])
})

function optionLabel(index) {
  return ['A', 'B', 'C', 'D'][index]
}

function resetAnswers() {
  Object.keys(answers).forEach((key) => delete answers[key])
  result.value = null
}

async function loadQuestions() {
  loading.value = true
  message.text = ''
  resetAnswers()
  try {
    questions.value = await examApi.questions(subject.value)
  } catch (error) {
    message.text = error.message
    message.type = 'error'
  } finally {
    loading.value = false
  }
}

async function submitExam() {
  submitting.value = true
  message.text = ''
  try {
    result.value = await examApi.submit({
      studentName: studentName.value,
      subject: subject.value,
      answers: { ...answers }
    })
    message.text = result.value.record.passed ? '模拟考试已通过' : '未达合格线，已生成补考记录'
    message.type = result.value.record.passed ? 'success' : 'error'
  } catch (error) {
    message.text = error.message
    message.type = 'error'
  } finally {
    submitting.value = false
  }
}

onMounted(loadQuestions)
</script>

<template>
  <section class="module-grid exam-layout">
    <section class="panel exam-paper">
      <div class="panel-heading">
        <div>
          <h3>模拟考试</h3>
          <p>提交后自动评分，不合格记录进入补考管理。</p>
        </div>
        <ClipboardCheck :size="20" />
      </div>

      <div class="toolbar">
        <label>
          <span>学员姓名</span>
          <input v-model.trim="studentName" placeholder="请输入姓名" />
        </label>
        <label>
          <span>考试科目</span>
          <select v-model="subject" @change="loadQuestions">
            <option v-for="item in subjects" :key="item">{{ item }}</option>
          </select>
        </label>
      </div>

      <MessageBar :message="message.text" :type="message.type" />

      <EmptyState v-if="!loading && questions.length === 0" title="暂无题目" description="该科目还没有配置题库。" />

      <div v-for="(question, index) in questions" :key="question.id" class="question-block">
        <strong>{{ index + 1 }}. {{ question.question }}</strong>
        <div class="option-grid">
          <label v-for="(option, optionIndex) in question.options" :key="option" class="choice">
            <input v-model="answers[question.id]" type="radio" :name="`q-${question.id}`" :value="optionLabel(optionIndex)" />
            <span>{{ optionLabel(optionIndex) }}. {{ option }}</span>
          </label>
        </div>
      </div>

      <button class="primary-button" :disabled="!canSubmit || submitting" type="button" @click="submitExam">
        <Send :size="18" />
        <span>{{ submitting ? '评分中' : '提交试卷' }}</span>
      </button>
    </section>

    <aside class="panel result-panel">
      <h3>考试结果</h3>
      <EmptyState v-if="!result" title="尚未交卷" description="完成所有题目后可查看得分。" />
      <div v-else class="score-result">
        <span class="score-number">{{ result.record.score }}</span>
        <strong>{{ result.record.passed ? '合格' : '不合格' }}</strong>
        <p>答对 {{ result.record.correctCount }} / {{ result.record.totalQuestions }} 题</p>
        <p v-if="result.makeup">补考状态：{{ result.makeup.status }}</p>
      </div>
    </aside>
  </section>
</template>
