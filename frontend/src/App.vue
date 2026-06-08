<script setup>
import { computed, ref } from 'vue'
import {
  CalendarCheck,
  ClipboardList,
  FileText,
  RotateCcw,
  SlidersHorizontal
} from 'lucide-vue-next'

import AppointmentView from './views/AppointmentView.vue'
import ExamView from './views/ExamView.vue'
import ScoresView from './views/ScoresView.vue'
import MakeupView from './views/MakeupView.vue'
import RulesView from './views/RulesView.vue'

const navItems = [
  { key: 'appointments', label: '科目预约', icon: CalendarCheck, component: AppointmentView },
  { key: 'exam', label: '模拟考试', icon: ClipboardList, component: ExamView },
  { key: 'scores', label: '成绩查询', icon: FileText, component: ScoresView },
  { key: 'makeups', label: '补考管理', icon: RotateCcw, component: MakeupView },
  { key: 'rules', label: '约考规则', icon: SlidersHorizontal, component: RulesView }
]

const activeKey = ref('appointments')
const activeItem = computed(() => navItems.find((item) => item.key === activeKey.value))
</script>

<template>
  <div class="app-shell">
    <aside class="sidebar">
      <div class="brand">
        <div class="brand-mark">驾</div>
        <div>
          <h1>驾考科目预约系统</h1>
          <p>预约、考试、成绩与补考管理</p>
        </div>
      </div>

      <nav class="nav-list" aria-label="主导航">
        <button
          v-for="item in navItems"
          :key="item.key"
          class="nav-button"
          :class="{ active: activeKey === item.key }"
          type="button"
          @click="activeKey = item.key"
        >
          <component :is="item.icon" :size="18" />
          <span>{{ item.label }}</span>
        </button>
      </nav>
    </aside>

    <main class="content">
      <header class="topbar">
        <div>
          <span class="eyebrow">Driving Exam Admin</span>
          <h2>{{ activeItem.label }}</h2>
        </div>
      </header>

      <component :is="activeItem.component" />
    </main>
  </div>
</template>
