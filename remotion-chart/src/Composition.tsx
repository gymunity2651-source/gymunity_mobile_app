import {
  AbsoluteFill,
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

type BarDatum = {
  label: string;
  value: number;
  color: string;
};

const data: BarDatum[] = [
  { label: "Search", value: 42, color: "#2f80ed" },
  { label: "Social", value: 68, color: "#00a878" },
  { label: "Email", value: 84, color: "#f2b705" },
  { label: "Events", value: 56, color: "#ef6f6c" },
  { label: "Direct", value: 73, color: "#6c63ff" },
];

const maxValue = 100;
const chartHeight = 390;
const chartBottom = 566;
const chartLeft = 210;
const chartWidth = 860;
const barWidth = 108;
const barGap = (chartWidth - data.length * barWidth) / (data.length - 1);

const clamp01 = (value: number) => Math.max(0, Math.min(1, value));

const containerStyle: React.CSSProperties = {
  background: "#f6f8fb",
  color: "#15181f",
  fontFamily:
    "Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",
};

const titleStyle: React.CSSProperties = {
  position: "absolute",
  top: 58,
  left: 84,
  margin: 0,
  fontSize: 58,
  lineHeight: 1,
  fontWeight: 800,
  letterSpacing: 0,
};

const subtitleStyle: React.CSSProperties = {
  position: "absolute",
  top: 128,
  left: 88,
  margin: 0,
  fontSize: 25,
  lineHeight: 1.35,
  color: "#596171",
  fontWeight: 500,
  letterSpacing: 0,
};

export const AnimatedBarChart: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const introOpacity = interpolate(frame, [0, 0.8 * fps], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  const axisProgress = interpolate(frame, [0.25 * fps, 1.2 * fps], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  const summaryOpacity = interpolate(frame, [3.2 * fps, 4.2 * fps], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  return (
    <AbsoluteFill style={containerStyle}>
      <div
        style={{
          ...titleStyle,
          opacity: introOpacity,
          transform: `translateY(${(1 - introOpacity) * 16}px)`,
        }}
      >
        Channel Growth
      </div>

      <div
        style={{
          ...subtitleStyle,
          opacity: introOpacity,
          transform: `translateY(${(1 - introOpacity) * 12}px)`,
        }}
      >
        Five acquisition channels ranked by monthly lift
      </div>

      <div
        style={{
          position: "absolute",
          left: chartLeft,
          top: chartBottom - chartHeight,
          width: chartWidth,
          height: chartHeight,
        }}
      >
        {[0, 25, 50, 75, 100].map((tick) => {
          const y = chartHeight - (tick / maxValue) * chartHeight;

          return (
            <div key={tick}>
              <div
                style={{
                  position: "absolute",
                  left: -74,
                  top: y - 13,
                  width: 44,
                  textAlign: "right",
                  color: "#8b93a3",
                  fontSize: 20,
                  fontWeight: 600,
                  opacity: axisProgress,
                  letterSpacing: 0,
                }}
              >
                {tick}
              </div>
              <div
                style={{
                  position: "absolute",
                  left: 0,
                  top: y,
                  height: 2,
                  width: chartWidth * axisProgress,
                  background: tick === 0 ? "#222833" : "#dfe4ec",
                  borderRadius: 2,
                }}
              />
            </div>
          );
        })}

        {data.map((item, index) => {
          const x = index * (barWidth + barGap);
          const delayedFrame = frame - index * 8;
          const progress = clamp01(
            spring({
              frame: delayedFrame,
              fps,
              config: {
                damping: 18,
                stiffness: 90,
                mass: 0.9,
              },
            }),
          );
          const height = (item.value / maxValue) * chartHeight * progress;
          const labelOpacity = interpolate(
            frame,
            [1.1 * fps + index * 6, 1.8 * fps + index * 6],
            [0, 1],
            {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            },
          );
          const value = Math.round(item.value * progress);

          return (
            <div
              key={item.label}
              style={{
                position: "absolute",
                left: x,
                bottom: 0,
                width: barWidth,
                height: chartHeight,
              }}
            >
              <div
                style={{
                  position: "absolute",
                  bottom: height + 18,
                  left: -12,
                  width: barWidth + 24,
                  textAlign: "center",
                  color: "#15181f",
                  fontSize: 28,
                  lineHeight: 1,
                  fontWeight: 800,
                  opacity: labelOpacity,
                  letterSpacing: 0,
                }}
              >
                {value}%
              </div>

              <div
                style={{
                  position: "absolute",
                  bottom: 0,
                  width: barWidth,
                  height,
                  borderRadius: "18px 18px 6px 6px",
                  background: item.color,
                  boxShadow: `0 24px 42px ${item.color}33`,
                  overflow: "hidden",
                }}
              >
                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    background:
                      "linear-gradient(180deg, rgba(255,255,255,0.42), rgba(255,255,255,0) 52%)",
                    opacity: 0.85,
                  }}
                />
              </div>

              <div
                style={{
                  position: "absolute",
                  top: chartHeight + 24,
                  left: -24,
                  width: barWidth + 48,
                  textAlign: "center",
                  color: "#363d4a",
                  fontSize: 23,
                  lineHeight: 1.2,
                  fontWeight: 700,
                  opacity: labelOpacity,
                  letterSpacing: 0,
                }}
              >
                {item.label}
              </div>
            </div>
          );
        })}
      </div>

      <div
        style={{
          position: "absolute",
          right: 86,
          bottom: 58,
          display: "flex",
          alignItems: "center",
          gap: 14,
          opacity: summaryOpacity,
          transform: `translateY(${(1 - summaryOpacity) * 18}px)`,
        }}
      >
        <div
          style={{
            width: 14,
            height: 14,
            borderRadius: 14,
            background: "#00a878",
          }}
        />
        <div
          style={{
            fontSize: 24,
            lineHeight: 1.25,
            color: "#363d4a",
            fontWeight: 700,
            letterSpacing: 0,
          }}
        >
          Email leads with 84% lift
        </div>
      </div>
    </AbsoluteFill>
  );
};
