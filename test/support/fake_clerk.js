// Minimal stand-in for Clerk's browser SDK, used only in the test environment
// so a real browser can drive the sign-up / sign-in / sign-out UI without
// Clerk keys or network access.
//
// mountSignIn / mountSignUp render a form that posts to the test-only
// /test/sign-in endpoint. signOut posts a DELETE to the application's real
// /sign-out route, so logout exercises the same controller as production.
(function () {
  "use strict";

  function buildForm(mountEl, action, label) {
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

    mountEl.appendChild(form);
  }

  window.Clerk = {
    loaded: false,
    user: null,

    load: function () {
      this.loaded = true;
      return Promise.resolve();
    },

    mountSignIn: function (mountEl) {
      buildForm(mountEl, "/test/sign-in", "Sign in");
    },

    mountSignUp: function (mountEl) {
      buildForm(mountEl, "/test/sign-in", "Create account");
    },

    signOut: function () {
      var form = document.createElement("form");
      form.method = "post";
      form.action = "/sign-out";

      var method = document.createElement("input");
      method.type = "hidden";
      method.name = "_method";
      method.value = "delete";
      form.appendChild(method);

      document.body.appendChild(form);
      form.submit();
      return Promise.resolve();
    }
  };
})();
