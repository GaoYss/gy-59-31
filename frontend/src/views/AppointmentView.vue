<script setup>
import { onMounted, reactive, ref } from 'vue'
import { CheckCircle2, RefreshCcw, Save } from 'lucide-vue-next'

import { appointmentApi } from '../api/modules'
import DataTable from '../components/DataTable.vue'
import EmptyState from '../components/EmptyState.vue'
import MessageBar from '../components/MessageBar.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { appointmentStatuses, subjects, timeSlots } from '../constants/options'

const appointments = ref([])
const loading = ref(false)
const saving = ref(false)
const message = reactive({ text: '', type: 'info' })

const form = reactive({
  studentName: '',
  idNumber: '',
  subject: '科目一',
  examDate: '',
  timeslot: timeSlots[0]
})

const columns = [
  { key: 'studentName', label: '学员' },
  { key: 'idNumber', label: '证件号' },
  { key: 'subject', label: '科目' },
  { key: 'examDate', label: '日期' },
  { key: 'timeslot', label: '时段' },
  { key: 'status', label: '状态' }
]

function setMessage(text, type = 'info') {
  message.text = text
  message.type = type
}

async function loadAppointments() {
  loading.value = true
  try {
    appointments.value = await appointmentApi.list()
  } catch (error) {
    setMessage(error.message, 'error')
  } finally {
    loading.value = false
  }
}

async function submitAppointment() {
  saving.value = true
  setMessage('')
  try {
    await appointmentApi.create({ ...form })
    Object.assign(form, {
      studentName: '',
      idNumber: '',
      subject: form.subject,
      examDate: '',
      timeslot: form.timeslot
    })
    setMessage('预约已提交', 'success')
    await loadAppointments()
  } catch (error) {
    setMessage(error.message, 'error')
  } finally {
    saving.value = false
  }
}

async function changeStatus(row, status) {
  try {
    await appointmentApi.updateStatus(row.id, status)
    await loadAppointments()
  } catch (error) {
    setMessage(error.message, 'error')
  }
}

onMounted(loadAppointments)
</script>

<template>
  <section class="module-grid two-columns">
    <form class="panel form-panel" @submit.prevent="submitAppointment">
      <div class="panel-heading">
        <div>
          <h3>新建预约</h3>
          <p>按约考规则校验日期、科目名额和重复预约。</p>
        </div>
        <Save :size="20" />
      </div>

      <MessageBar :message="message.text" :type="message.type" />

      <label>
        <span>学员姓名</span>
        <input v-model.trim="form.studentName" required placeholder="请输入姓名" />
      </label>
      <label>
        <span>证件号</span>
        <input v-model.trim="form.idNumber" required placeholder="身份证或档案号" />
      </label>
      <div class="field-row">
        <label>
          <span>预约科目</span>
          <select v-model="form.subject">
            <option v-for="subject in subjects" :key="subject">{{ subject }}</option>
          </select>
        </label>
        <label>
          <span>考试日期</span>
          <input v-model="form.examDate" required type="date" />
        </label>
      </div>
      <label>
        <span>考试时段</span>
        <select v-model="form.timeslot">
          <option v-for="slot in timeSlots" :key="slot">{{ slot }}</option>
        </select>
      </label>

      <button class="primary-button" :disabled="saving" type="submit">
        <CheckCircle2 :size="18" />
        <span>{{ saving ? '提交中' : '提交预约' }}</span>
      </button>
    </form>

    <section class="panel list-panel">
      <div class="panel-heading">
        <div>
          <h3>预约列表</h3>
          <p>维护当前预约状态。</p>
        </div>
        <button class="icon-button" type="button" title="刷新" @click="loadAppointments">
          <RefreshCcw :size="18" />
        </button>
      </div>

      <EmptyState
        v-if="!loading && appointments.length === 0"
        title="暂无预约"
        description="提交预约后将在这里显示。"
      />
      <DataTable v-else :columns="columns" :rows="appointments">
        <template #status="{ row }">
          <StatusBadge :status="row.status" />
        </template>
        <template #actions="{ row }">
          <select class="compact-select" :value="row.status" @change="changeStatus(row, $event.target.value)">
            <option v-for="status in appointmentStatuses" :key="status">{{ status }}</option>
          </select>
        </template>
      </DataTable>
    </section>
  </section>
</template>
