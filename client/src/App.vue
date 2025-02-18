<script setup>
import MarketChart from './components/MarketChart.vue'
import ChatBox from './components/ChatBox.vue'
</script>

<template>
  <div id="app" class="container my-5">
    <div class="row">
      <!-- Left column (Chart) -->
      <div class="col-md-8 mb-3">
        <div class="card bg-dark text-white">
          <div class="card-body">
            <MarketChart />
          </div>
        </div>
      </div>

      <!-- Right column (Chat) -->
      <div class="col-md-4 mb-3">
        <ChatBox />
      </div>
    </div>
  </div>
</template>

<style scoped>
.card-body {
  height: 440px;
}
</style>
