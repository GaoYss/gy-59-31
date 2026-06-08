<script setup>
defineProps({
  title: {
    type: String,
    required: true
  },
  description: {
    type: String,
    default: ''
  }
})
</script>

<template>
  <div class="empty-state">
    <strong>{{ title }}</strong>
    <span v-if="description">{{ description }}</span>
  </div>
</template>
