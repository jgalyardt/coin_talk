<template>
  <div class="market-chart h-100">
    <canvas ref="chartCanvas"></canvas>
    <div class="historical-data mt-3" v-if="historicalData">
      <h5>Historical Prices</h5>
      <ul>
        <li>Yesterday: ${{ historicalData.yesterday }}</li>
        <li>1 Week Ago: ${{ historicalData.week }}</li>
        <li>1 Month Ago: ${{ historicalData.month }}</li>
        <li>1 Year Ago: ${{ historicalData.year }}</li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import Chart from 'chart.js/auto'

const chartCanvas = ref(null)
let chartInstance = null
const dataPoints = ref([])       // Reactive array for current prices
const historicalData = ref(null) // Reactive object for historical data

// Function to add a random fluctuation of ±3
function addFluctuation(price) {
  const fluctuation = (Math.random() * 6 - 3).toFixed(2) // Random number between -3 and 3
  return parseFloat(price) + parseFloat(fluctuation)
}

async function fetchMarketData() {
  try {
    const response = await fetch('http://localhost:4000/api/charts')
    if (!response.ok) throw new Error('Failed to fetch market data')
    const data = await response.json()

    // Extract current price and apply fluctuation
    let price = addFluctuation(data.bitcoin.price)

    // Update historical data
    historicalData.value = { ...data.bitcoin.historical }

    // Update dataPoints
    const newDataPoints = [...dataPoints.value, price]
    if (newDataPoints.length > 20) newDataPoints.shift()
    dataPoints.value = newDataPoints

    if (chartInstance) {
      // Update chart data
      chartInstance.data.labels = newDataPoints.map((_, index) => index + 1)
      chartInstance.data.datasets[0].data = newDataPoints

      // Adjust y-axis scale: set min/max to ±10 from the latest price
      chartInstance.options.scales.y.min = price - 10
      chartInstance.options.scales.y.max = price + 10

      chartInstance.update()
    }
  } catch (error) {
    console.error(error)
  }
}

onMounted(() => {
  chartInstance = new Chart(chartCanvas.value, {
    type: 'line',
    data: {
      labels: [],
      datasets: [
        {
          label: 'Bitcoin Price (USD)',
          data: [],
          borderColor: 'rgba(75,192,192,1)',
          backgroundColor: 'rgba(75,192,192,0.1)',
          tension: 0.3,
          fill: true,
        },
      ],
    },
    options: {
      scales: {
        y: { beginAtZero: false } // min and max will be set after fetching data
      },
      responsive: true,
      maintainAspectRatio: false,
    },
  })

  // Fetch data immediately, then poll every 5 seconds.
  fetchMarketData()
  setInterval(fetchMarketData, 5000)
})
</script>

<style scoped>
.historical-data {
  font-size: 0.9rem;
}
</style>
