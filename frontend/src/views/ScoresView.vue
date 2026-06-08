<script setup>
import { onMounted, reactive, ref } from 'vue'
import { Search } from 'lucide-vue-next'

import { scoreApi } from '../api/modules'
import DataTable from '../components/DataTable.vue'
import EmptyState from '../components/EmptyState.vue'
import MessageBar from '../components/MessageBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { subjects } from '../constants/options'

const scores = ref([])
const loading = ref(false)
const message = reactive({ text: '', type: 'info' })
const filters = reactive({ studentName: '', subject: '' })

const columns = [
  { key: 'studentName', label: '学员' },
  { key: 'subject', label: '科目' },
  { key: 'score', label: '分数' },
  { key: 'correctCount', label: '答对' },
  { key: 'passed', label: '结果' },
  { key: 'submittedAt', label: '提交时间' }
]

async function loadScores() {
  loading.value = true
  message.text = ''
  try {
    const params = {}
    if (filters.studentName) params.studentName = filters.studentName
    if (filters.subject) params.subject = filters.subject
    scores.value = await scoreApi.list(params)
  } catch (error) {
    message.text = error.message
    message.type = 'error'
  } finally {
    loading.value = false
  }
}

onMounted(loadScores)
</script>

<template>
  <section class="panel">
    <div class="panel-heading">
      <div>
        <h3>成绩查询</h3>
        <p>按学员或科目筛选模拟考试记录。</p>
      </div>
    </div>

    <form class="toolbar" @submit.prevent="loadScores">
      <label>
        <span>学员姓名</span>
        <input v-model.trim="filters.studentName" placeholder="输入姓名检索" />
      </label>
      <label>
        <span>科目</span>
        <select v-model="filters.subject">
          <option value="">全部科目</option>
          <option v-for="subject in subjects" :key="subject">{{ subject }}</option>
        </select>
      </label>
      <button class="primary-button inline-button" type="submit">
        <Search :size="18" />
        <span>查询</span>
      </button>
    </form>

    <MessageBar :message="message.text" :type="message.type" />

    <EmptyState v-if="!loading && scores.length === 0" title="暂无成绩" description="模拟考试提交后会生成成绩。" />
    <DataTable v-else :columns="columns" :rows="scores">
      <template #passed="{ row }">
        <StatusBadge :status="row.passed ? '合格' : '不合格'" />
      </template>
      <template #correctCount="{ row }">
        {{ row.correctCount }} / {{ row.totalQuestions }}
      </template>
    </DataTable>
  </section>
</template>
