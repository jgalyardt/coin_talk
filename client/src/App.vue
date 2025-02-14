<script setup>
import MarketChart from './components/MarketChart.vue'
import ChatBox from './components/ChatBox.vue'
</script>

<template>
  <div id="app">
    <div class="container">
      <div class="row">
        <div class="col-md-8">
          <MarketChart />
        </div>
        <div class="col-md-4">
          <ChatBox />
        </div>
      </div>
    </div>

  </div>
</template>
