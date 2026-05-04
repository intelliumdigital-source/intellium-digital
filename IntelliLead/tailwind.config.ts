import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: "#040816",
        panel: "#0b132c",
        line: "#1a2550",
        cyan: "#3df2ff",
        blue: "#4b7bff",
        violet: "#865dff",
        success: "#1bdd9d",
        warning: "#ffc857",
        danger: "#ff6b81"
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(61,242,255,0.18), 0 20px 60px rgba(10,20,45,0.55)",
        neon: "0 0 40px rgba(61,242,255,0.22)"
      },
      backgroundImage: {
        "hero-grid":
          "linear-gradient(rgba(255,255,255,0.04) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.04) 1px, transparent 1px)"
      }
    }
  },
  plugins: []
};

export default config;
