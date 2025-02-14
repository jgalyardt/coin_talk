<template>
  <div class="card h-100 d-flex flex-column">
    <div class="card-header">
      Chat
    </div>

    <!-- Chat messages -->
    <div class="card-body overflow-auto" ref="messagesContainer" style="flex: 1">
      <div
        v-for="message in messages"
        :key="message.id"
        class="mb-3"
      >
        <div class="fw-bold">{{ message.sender }}:</div>
        <div>{{ message.content }}</div>
        <div class="text-muted small">{{ message.inserted_at }}</div>
      </div>
    </div>

    <!-- Chat input form -->
    <div class="card-footer">
      <form @submit.prevent="sendMessage" class="d-flex">
        <input
          v-model="newMessage.content"
          type="text"
          class="form-control me-2"
          placeholder="Type your message..."
          required
        />
        <button type="submit" class="btn btn-primary">
          Send
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'

const messages = ref([])
const newMessage = ref({ sender: 'User', content: '' })
const messagesContainer = ref(null)

async function fetchChatMessages() {
  try {
    const res = await fetch('http://localhost:4000/api/chat')
    if (!res.ok) throw new Error('Failed to fetch chat messages')
    const data = await res.json()
    messages.value = data.messages

    await nextTick()
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  } catch (error) {
    console.error(error)
  }
}

async function sendMessage() {
  if (!newMessage.value.content.trim()) return
  try {
    const res = await fetch('http://localhost:4000/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newMessage.value)
    })
    if (!res.ok) {
      const errorData = await res.json()
      console.error('Error sending message:', errorData.errors)
      return
    }
    const data = await res.json()
    messages.value.push(data.message)
    newMessage.value.content = ''
    await nextTick()
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  } catch (error) {
    console.error(error)
  }
}

onMounted(() => {
  // initial load
  fetchChatMessages()
  // poll for new messages every 5 seconds
  setInterval(fetchChatMessages, 5000)
})
</script>

<style scoped>
</style>
