import type { SVGProps } from "react";

const VoiceMark = ({
  width = 24,
  height = 24,
  ...props
}: SVGProps<SVGSVGElement>) => (
  <svg
    width={width}
    height={height}
    viewBox="0 0 32 32"
    fill="none"
    aria-hidden="true"
    {...props}
  >
    <path
      d="M4 21c3 0 3-10 6-10s3 9 6 9 3-9 6-9 3 10 6 10"
      stroke="currentColor"
      strokeWidth="3"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
export default VoiceMark;
