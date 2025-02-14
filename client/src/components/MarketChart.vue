<template>
    <div class="market-chart">
      <canvas ref="chartCanvas"></canvas>
    </div>
  </template>
  
  <script setup>
  import { onMounted, ref } from 'vue'
  import Chart from 'chart.js/auto'
  
  const chartCanvas = ref(null)
  let chartInstance = null
  const dataPoints = []  // store the latest bitcoin prices
  
  async function fetchMarketData() {
    try {
      const response = await fetch('http://localhost:4000/api/charts')
      if (!response.ok) throw new Error('Failed to fetch market data')
      const data = await response.json()
      const price = data.bitcoin.price
  
      // add the new price point and limit history to the last 20 values
      dataPoints.push(price)
      if (dataPoints.length > 20) dataPoints.shift()
  
      // update the chart if it exists
      if (chartInstance) {
        chartInstance.data.labels = dataPoints.map((_, index) => index + 1)
        chartInstance.data.datasets[0].data = dataPoints
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
        datasets: [{
          label: 'Bitcoin Price (USD)',
          data: [],
          borderColor: 'rgba(75,192,192,1)',
          backgroundColor: 'rgba(75,192,192,0.1)',
          tension: 0.3,
          fill: true,
        }],
      },
      options: {
        scales: {
          y: { beginAtZero: false }
        },
        responsive: true,
        maintainAspectRatio: false,
      }
    })
  
    // fetch initial data and then update every 5 seconds
    fetchMarketData()
    setInterval(fetchMarketData, 5000)
  })
  </script>
  
  <style scoped>
  .market-chart {
    padding: 1rem;
    height: 100%;
  }
  </style>
  