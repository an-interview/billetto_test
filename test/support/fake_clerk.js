// Minimal stand-in for Clerk's browser SDK, used only in the test environment
// so a real browser can drive the sign-up / sign-in / sign-out UI without
// Clerk keys or network access.
//
// mountSignIn / mountSignUp render a form that posts to the test-only
// /test/sign-in endpoint. After the session is established, the fake follows
// the component's fallbackRedirectUrl / forceRedirectUrl option, mirroring the
// real Clerk redirect behavior. signOut revokes the fake client session and
// notifies listeners, like clerk-js; the sign-out Stimulus controller then
// submits the real DELETE /sign-out form, so logout exercises the same Rails
// controller as production.
(function () {
  "use strict";

  function buildForm(mountEl, action, label, options) {
    mountEl.innerHTML = "";

    var form = document.createElement("form");
    form.method = "post";
    form.action = action;

    var input = document.createElement("input");
    input.type = "text";
    input.id = "user_id";
    input.name = "user_id";
    input.placeholder = "user_id";
    input.required = true;
    form.appendChild(input);

    var button = document.createElement("button");
    button.type = "submit";
    button.textContent = label;
    form.appendChild(button);

    form.addEventListener("submit", function (event) {
      event.preventDefault();

      fetch(action, {
        method: "post",
        body: new FormData(form),
        credentials: "same-origin"
      }).then(function () {
        var redirectUrl = options.forceRedirectUrl || options.fallbackRedirectUrl;
        if (redirectUrl) window.location.assign(redirectUrl);
      });
    });

    mountEl.appendChild(form);
  }

  window.Clerk = {
    loaded: false,
    listeners: [],
    lastMountOptions: {},
    user: null,

    load: function () {
      this.loaded = true;
      return Promise.resolve();
    },

    addListener: function (callback) {
      this.listeners.push(callback);
      callback({ client: null, session: null, user: this.user });

      var listeners = this.listeners;
      return function () {
        var index = listeners.indexOf(callback);
        if (index >= 0) listeners.splice(index, 1);
      };
    },

    notify: function () {
      this.listeners.forEach(function (listener) {
        listener({ client: null, session: null, user: window.Clerk.user });
      });
    },

    mountSignIn: function (mountEl, options) {
      options = options || {};
      this.lastMountOptions = options;
      buildForm(mountEl, "/test/sign-in", "Sign in", options);
    },

    mountSignUp: function (mountEl, options) {
      options = options || {};
      this.lastMountOptions = options;
      buildForm(mountEl, "/test/sign-in", "Create account", options);
    },

    unmountSignIn: function (mountEl) {
      mountEl.innerHTML = "";
    },

    unmountSignUp: function (mountEl) {
      mountEl.innerHTML = "";
    },

    // Mirrors clerk-js: revoke the client session and notify listeners. The
    // fake never navigates; the sign-out controller submits the Rails form,
    // which is the only navigation in the flow.
    signOut: function (options) {
      options = options || {};

      var calls = parseInt(sessionStorage.getItem("fakeClerkSignOutCalls") || "0", 10);
      sessionStorage.setItem("fakeClerkSignOutCalls", String(calls + 1));

      this.user = null;
      this.notify();

      return Promise.resolve();
    }
  };
})();
