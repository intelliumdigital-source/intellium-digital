"use client";

import { useEffect, useState } from "react";

import { defaultChecklistItems } from "@/lib/data/outreach-kit";

export function DailyChecklist({ userId }: { userId: string }) {
  const storageKey = `daily-checklist:${userId}:${new Date().toISOString().slice(0, 10)}`;
  const [checkedItems, setCheckedItems] = useState<Record<string, boolean>>({});

  useEffect(() => {
    const savedState = window.localStorage.getItem(storageKey);
    if (savedState) {
      setCheckedItems(JSON.parse(savedState));
    }
  }, [storageKey]);

  useEffect(() => {
    window.localStorage.setItem(storageKey, JSON.stringify(checkedItems));
  }, [checkedItems, storageKey]);

  return (
    <div className="stack">
      {defaultChecklistItems.map((item) => (
        <label
          key={item}
          className="card"
          style={{ display: "flex", gap: "0.9rem", alignItems: "flex-start" }}
        >
          <input
            type="checkbox"
            checked={Boolean(checkedItems[item])}
            onChange={(event) =>
              setCheckedItems((current) => ({
                ...current,
                [item]: event.target.checked
              }))
            }
            style={{ width: 18, height: 18, marginTop: 2 }}
          />
          <span>{item}</span>
        </label>
      ))}
    </div>
  );
}
