<template>
    <div class="chat-box">
      <div class="messages" ref="messagesContainer">
        <div
          v-for="message in messages"
          :key="message.id"
          class="chat-message"
        >
          <div class="sender"><strong>{{ message.sender }}:</strong></div>
          <div class="content">{{ message.content }}</div>
          <div class="timestamp">{{ message.inserted_at }}</div>
        </div>
      </div>
      <form @submit.prevent="sendMessage" class="chat-form">
        <input
          v-model="newMessage.content"
          placeholder="Type your message..."
          required
        />
        <button type="submit">Send</button>
      </form>
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
  
      // scroll to the bottom so that the latest messages are visible
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
      // Append the new message to the list
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
  .chat-box {
    display: flex;
    flex-direction: column;
    height: 100%;
    border: 1px solid var(--color-border);
    border-radius: 4px;
    padding: 1rem;
  }
  
  .messages {
    flex: 1;
    overflow-y: auto;
    margin-bottom: 1rem;
    padding-right: 0.5rem;
  }
  
  .chat-message {
    margin-bottom: 0.8rem;
    padding: 0.4rem;
    border-bottom: 1px solid var(--color-border);
  }
  
  .sender {
    margin-bottom: 0.2rem;
  }
  
  .timestamp {
    font-size: 0.75rem;
    color: gray;
    text-align: right;
  }
  
  .chat-form {
    display: flex;
  }
  
  .chat-form input {
    flex: 1;
    padding: 0.5rem;
    border: 1px solid var(--color-border);
    border-radius: 4px;
    margin-right: 0.5rem;
  }
  
  .chat-form button {
    padding: 0.5rem 1rem;
    background-color: var(--vt-c-indigo);
    color: #fff;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }
  
  .chat-form button:hover {
    background-color: rgba(44, 62, 80, 0.8);
  }
  </style>
  