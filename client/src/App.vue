<script setup>
import MarketChart from './components/MarketChart.vue'
import ChatBox from './components/ChatBox.vue'
</script>

<template>
  <div id="app">
    <MarketChart />
    <ChatBox />
  </div>
</template>

<style scoped>
#app {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
  height: 100vh;
}
</style>
