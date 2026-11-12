/** Whether a call's output is shown under its row. */
export type IsOpen = boolean;

/** The animation frame of the running rows' shimmer; only ever counts up. */
export type Frame = number;

declare module "claude-code" {
  interface PluginState {
    "shell-list": {
      // One flag per tool call, keyed by its tool_use_id.
      isOpen: StateFamily<IsOpen>;
      frame: Frame;
    };
  }
}
