<script setup>
defineProps({
  status: {
    type: String,
    required: true
  }
})
</script>

<template>
  <span class="status-badge" :data-status="status">{{ status }}</span>
</template>
