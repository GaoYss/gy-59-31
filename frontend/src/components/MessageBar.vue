<script setup>
defineProps({
  message: {
    type: String,
    default: ''
  },
  type: {
    type: String,
    default: 'info'
  }
})
</script>

<template>
  <div v-if="message" class="message-bar" :data-type="type">
    {{ message }}
  </div>
</template>
