# Chrome policy baseline. NixOS module — import from configuration.nix.
{ ... }:

{
  programs.chromium = {
    enable = true;

    extraOptsRecommended = {
      # sign-in & sync
      BrowserSignin = 0;
      SyncDisabled = true;
      MetricsReportingEnabled = false;

      # passwords, autofill & payments are keepassxc's job
      PasswordManagerEnabled = false;
      PasswordLeakDetectionEnabled = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      PaymentMethodQueryEnabled = false;

      # no phoning home while typing or browsing
      SearchSuggestEnabled = false;
      NetworkPredictionOptions = 2;

      # ui noise
      SpellcheckEnabled = false;
      TranslateEnabled = false;
      DefaultBrowserSettingEnabled = false;
      PromotionalTabsEnabled = false;
      BackgroundModeEnabled = false;
    };
  };
}
