<template>
  <div class="card h-100 d-flex flex-column bg-dark text-white">
    <!-- Sticky 'typing...' indicator at the bottom -->

    <div v-if="typingIndicator" class="typing-indicator position-absolute w-100">
      <em>{{ typingIndicator }}</em>
    </div>

    <!-- Chat messages container -->
    <div class="card-body overflow-auto position-relative" ref="messagesContainer"
      style="flex: 1; padding-bottom: 2em;">
      <!-- Render non-typing messages -->
      <div v-for="message in nonTypingMessages" :key="message.id" class="mb-3">
        <div class="fw-bold">{{ message.sender }}:</div>
        <div>{{ message.content }}</div>
        <div class="text-muted small">{{ message.inserted_at }}</div>
      </div>


    </div>

    <!-- Chat input form -->
    <div class="card-footer">
      <form @submit.prevent="sendMessage" class="d-flex">
        <input v-model="newMessage.content" type="text" class="form-control me-2" placeholder="Type your message..."
          required />
        <button type="submit" class="btn btn-primary">
          Send
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, computed } from 'vue'

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
  // Initial load and polling for new messages.
  fetchChatMessages()
  setInterval(fetchChatMessages, 5000)
})

// Computed property: filter out messages ending with "is typing..."
const nonTypingMessages = computed(() => {
  return messages.value.filter(m => !m.content.trim().endsWith("is typing..."))
})

// Computed property: get a unique list of senders with a "typing..." message
const typingSenders = computed(() => {
  const senders = messages.value
    .filter(m => m.content.trim().endsWith("is typing..."))
    .map(m => m.sender)
  return [...new Set(senders)]
})

// Computed property: format the typing indicator text.
const typingIndicator = computed(() => {
  const senders = typingSenders.value
  if (senders.length === 0) return ''
  if (senders.length === 1) return `${senders[0]} is typing...`
  if (senders.length === 2) return `${senders[0]} and ${senders[1]} are typing...`
  return `${senders.length} people are typing...`
})
</script>

<style scoped>
.typing-indicator {
  bottom: 55px;
  padding: 5px;
  filter: opacity(0.5);
}

.card-body {
  max-height: 388px;
}
</style>
