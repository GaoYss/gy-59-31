<script setup>
import { onMounted, reactive, ref } from 'vue'
import { Plus, RefreshCcw } from 'lucide-vue-next'

import { makeupApi } from '../api/modules'
import DataTable from '../components/DataTable.vue'
import EmptyState from '../components/EmptyState.vue'
import MessageBar from '../components/MessageBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { makeupStatuses, subjects } from '../constants/options'

const makeups = ref([])
const loading = ref(false)
const saving = ref(false)
const message = reactive({ text: '', type: 'info' })
const form = reactive({
  studentName: '',
  originalSubject: '科目二',
  failedScore: 0,
  scheduledDate: '',
  notes: ''
})

const columns = [
  { key: 'studentName', label: '学员' },
  { key: 'originalSubject', label: '原科目' },
  { key: 'failedScore', label: '失败分数' },
  { key: 'scheduledDate', label: '补考日期' },
  { key: 'status', label: '状态' },
  { key: 'notes', label: '备注' }
]

async function loadMakeups() {
  loading.value = true
  try {
    makeups.value = await makeupApi.list()
  } catch (error) {
    message.text = error.message
    message.type = 'error'
  } finally {
    loading.value = false
  }
}

async function createMakeup() {
  saving.value = true
  message.text = ''
  try {
    await makeupApi.create({ ...form })
    Object.assign(form, {
      studentName: '',
      originalSubject: form.originalSubject,
      failedScore: 0,
      scheduledDate: '',
      notes: ''
    })
    message.text = '补考记录已创建'
    message.type = 'success'
    await loadMakeups()
  } catch (error) {
    message.text = error.message
    message.type = 'error'
  } finally {
    saving.value = false
  }
}

async function updateMakeup(row, payload) {
  try {
    await makeupApi.update(row.id, payload)
    await loadMakeups()
  } catch (error) {
    message.text = error.message
    message.type = 'error'
  }
}

onMounted(loadMakeups)
</script>

<template>
  <section class="module-grid two-columns">
    <form class="panel form-panel" @submit.prevent="createMakeup">
      <div class="panel-heading">
        <div>
          <h3>新增补考</h3>
          <p>模拟考试未通过会自动生成，也可手动登记。</p>
        </div>
        <Plus :size="20" />
      </div>

      <MessageBar :message="message.text" :type="message.type" />

      <label>
        <span>学员姓名</span>
        <input v-model.trim="form.studentName" required placeholder="请输入姓名" />
      </label>
      <div class="field-row">
        <label>
          <span>原科目</span>
          <select v-model="form.originalSubject">
            <option v-for="subject in subjects" :key="subject">{{ subject }}</option>
          </select>
        </label>
        <label>
          <span>失败分数</span>
          <input v-model.number="form.failedScore" min="0" max="100" type="number" />
        </label>
      </div>
      <label>
        <span>补考日期</span>
        <input v-model="form.scheduledDate" type="date" />
      </label>
      <label>
        <span>备注</span>
        <textarea v-model.trim="form.notes" rows="3" placeholder="训练重点或失败原因"></textarea>
      </label>

      <button class="primary-button" :disabled="saving" type="submit">
        <Plus :size="18" />
        <span>{{ saving ? '保存中' : '登记补考' }}</span>
      </button>
    </form>

    <section class="panel list-panel">
      <div class="panel-heading">
        <div>
          <h3>补考列表</h3>
          <p>安排补考日期并跟踪处理状态。</p>
        </div>
        <button class="icon-button" type="button" title="刷新" @click="loadMakeups">
          <RefreshCcw :size="18" />
        </button>
      </div>

      <EmptyState v-if="!loading && makeups.length === 0" title="暂无补考" description="补考记录将在这里显示。" />
      <DataTable v-else :columns="columns" :rows="makeups">
        <template #status="{ row }">
          <StatusBadge :status="row.status" />
        </template>
        <template #scheduledDate="{ row }">
          <input
            class="table-input"
            type="date"
            :value="row.scheduledDate || ''"
            @change="updateMakeup(row, { scheduledDate: $event.target.value, status: row.status === '待安排' ? '已安排' : row.status })"
          />
        </template>
        <template #actions="{ row }">
          <select class="compact-select" :value="row.status" @change="updateMakeup(row, { status: $event.target.value })">
            <option v-for="status in makeupStatuses" :key="status">{{ status }}</option>
          </select>
        </template>
      </DataTable>
    </section>
  </section>
</template>
