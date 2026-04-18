# Animated Bar Chart

Remotion composition for a five-bar animated channel growth chart.

## Commands

Install dependencies:

```console
npm install
```

Start Remotion Studio:

```console
npm run dev -- src/index.ts --port=3000 --no-open
```

Render the MP4:

```console
npx remotion render src/index.ts AnimatedBarChart out/animated-bar-chart.mp4 --codec=h264 --crf=18
```

Render a still frame:

```console
npx remotion still src/index.ts AnimatedBarChart out/animated-bar-chart-frame.png --scale=0.5 --frame=60
```
