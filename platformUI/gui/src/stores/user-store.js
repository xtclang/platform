import { defineStore } from 'pinia';
import { apiUser } from "boot/axios";
import { useQuasar } from "quasar";

export const useUserStore = defineStore('user', {
  state: () => ({
    user: null,
    $q: useQuasar()
  }),

  getters: {
    hasUser: (state) => state.user != null
  },

  actions: {
    updateUser() {
      // const $q = useQuasar();
      apiUser
        .get("/id")
        .then((response) => {
          if (response.status === 200) {
            this.user = response.data;
          } else {
            this.user = null;
          }

        })
        .catch(() => {
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Could not fetch user information",
            icon: "report_problem",
          });
        });
    },

    logIn() {
      apiUser
        .get("/login")
        .then((response) => {
          this.user = response.data;
        })
        .catch(() => {
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Login failed",
            icon: "report_problem",
          });
        });
    },

    logOut() {
      apiUser
        .put("/logout", {}, {
          auth: {
            username: "___",
            password: "___"
          }
        })
        .then((response) => {
          this.user = null;
        })
        .catch(() => {
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Logout failed",
            icon: "report_problem",
          });
        });
    },
  },
});
