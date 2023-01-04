import Chart from 'chart.js/auto'

const legendColor = '#F1F5F9'
const gridColor = '#475569'
const tickColor = '#94a3b8'

const chartOptions = (max) => {
    return {
        responsive: true,
        plugins: {
            legend: {
                position: "bottom",
                labels: {
                    usePointStyle: true,
                    padding: 16,
                    boxHeight: 8,
                    color: legendColor,
                    font: {
                        size: 16,
                    }
                }
            }
        },
        maintainAspectRatio: false,
        scales: {
            x: {
                grid: {
                    display: false
                },
                ticks: {
                    color: tickColor,
                    maxTicksLimit: 12,
                    font: {
                        size: 14,
                    }
                }
            },
            y: {
                min: 0, 
                max,
                color: '#374151',
                grid: {
                    color: gridColor,
                },
                ticks: {
                    stepSize: 10,
                    precision: 0,
                    maxTicksLimit: 7,
                    color: tickColor,
                    font: {
                        size: 14,
                    }
                }
            }
        }
    }
}

const insertOrUpdateGraph = (el) => {
    const labels = JSON.parse(el.dataset.labels).map(timeString => {
        const date = new Date(timeString)
        return date.toLocaleString(undefined, { hour: '2-digit' })
    })
    const rawDatasets = JSON.parse(el.dataset.datasets)
    const opensDataset = rawDatasets.find(({id}) => id === "opens")
    const clicksDataset = rawDatasets.find(({id}) => id === "clicks")
    const datasets = [
        {
            id: opensDataset.id,
            borderColor: "rgb(8, 145, 178)",
            pointBackgroundColor: "rgb(8, 145, 178)",
            data: opensDataset.data,
            label: opensDataset.label,
            tension: 0.075,
            fill: true
        },
        {
            id: clicksDataset.id,
            borderColor: "rgb(147, 51, 234)",
            pointBackgroundColor: "rgb(147, 51, 234)",
            data: clicksDataset.data,
            label: clicksDataset.label,
            tension: 0.075,
            fill: true
        },
    ]

    const maxValue = opensDataset.data.reduce((acc, v) => {
        return v > acc ? v : acc
    }, 10)
    const max = Math.ceil(maxValue*1.1/10)*10

    const chart = Chart.getChart(el)
    if (chart) {
        chart.data.datasets.forEach(chartDataset => {
            updatedDataset = datasets.find(({id}) => id == chartDataset.id)
            chartDataset.data.forEach((_v, i) => {
                chartDataset.data[i] = updatedDataset.data[i]
            })
        })

        chart.data.datasets = datasets
        chart.options.scales.y.max = max
        chart.update()
    }
    else {
        new Chart(el, {
            type: 'line',
            data: { labels, datasets },
            options: chartOptions(max)
        })
    }
}

export default {
    mounted() {
        insertOrUpdateGraph(this.el)
    },
    updated() {
        insertOrUpdateGraph(this.el)
    }
}
