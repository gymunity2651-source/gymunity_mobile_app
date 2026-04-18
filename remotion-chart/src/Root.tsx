import "./index.css";
import { Composition } from "remotion";
import { AnimatedBarChart } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="AnimatedBarChart"
        component={AnimatedBarChart}
        durationInFrames={150}
        fps={30}
        width={1280}
        height={720}
      />
    </>
  );
};
