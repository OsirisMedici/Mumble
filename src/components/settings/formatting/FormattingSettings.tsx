import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { commands } from "@/bindings";
import { useSettings } from "../../../hooks/useSettings";
import { SettingsGroup } from "../../ui/SettingsGroup";
import { ToggleSwitch } from "../../ui/ToggleSwitch";

export const FormattingSettings = () => {
  const { t } = useTranslation();
  const { getSetting, updateSetting, isUpdating } = useSettings();
  const enabled = getSetting("number_formatting_enabled") ?? false;
  const emailsEnabled = getSetting("email_formatting_enabled") ?? false;
  const emailsUpdating = isUpdating("email_formatting_enabled");
  const updating = isUpdating("number_formatting_enabled");
  const [example, setExample] = useState(() =>
    t("settings.formatting.preview.example"),
  );
  const [preview, setPreview] = useState<string | null>(null);
  const [previewFailed, setPreviewFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setPreview(null);
    setPreviewFailed(false);
    if (updating || emailsUpdating) return;
    const timer = setTimeout(() => {
      void commands.previewFormatting(example).then(
        (text) => {
          if (!cancelled) setPreview(text);
        },
        () => {
          if (!cancelled) setPreviewFailed(true);
        },
      );
    }, 150);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [example, enabled, emailsEnabled, updating, emailsUpdating]);

  return (
    <div className="max-w-3xl w-full mx-auto space-y-6">
      <SettingsGroup title={t("settings.formatting.title")}>
        <ToggleSwitch
          checked={enabled}
          onChange={(enabled) =>
            updateSetting("number_formatting_enabled", enabled)
          }
          isUpdating={updating}
          label={t("settings.formatting.numbers.title")}
          description={t("settings.formatting.numbers.description")}
          descriptionMode="inline"
          grouped
        />
        <ToggleSwitch
          checked={emailsEnabled}
          onChange={(value) => updateSetting("email_formatting_enabled", value)}
          isUpdating={emailsUpdating}
          label={t("settings.formatting.emails.title")}
          description={t("settings.formatting.emails.description")}
          descriptionMode="inline"
          grouped
        />
      </SettingsGroup>
      <SettingsGroup
        title={t("settings.formatting.preview.title")}
        description={t("settings.formatting.preview.description")}
      >
        <div className="p-4 space-y-4">
          <div className="space-y-2">
            <label
              htmlFor="formatting-preview"
              className="block text-sm font-medium"
            >
              {t("settings.formatting.preview.input")}
            </label>
            <textarea
              id="formatting-preview"
              value={example}
              onChange={(event) => setExample(event.target.value)}
              maxLength={2000}
              rows={2}
              className="w-full resize-y rounded-md border border-mid-gray/30 bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-logo-primary"
            />
          </div>
          <div className="space-y-2">
            <p className="text-sm font-medium">
              {t("settings.formatting.preview.output")}
            </p>
            <output
              aria-live="polite"
              className="block min-h-16 whitespace-pre-wrap break-words rounded-md bg-mid-gray/10 px-3 py-3 text-sm"
            >
              {previewFailed
                ? t("settings.formatting.preview.error")
                : (preview ?? t("settings.formatting.preview.loading"))}
            </output>
          </div>
          <p className="text-xs text-mid-gray">
            {t("settings.formatting.preview.hint")}
          </p>
        </div>
      </SettingsGroup>
    </div>
  );
};
