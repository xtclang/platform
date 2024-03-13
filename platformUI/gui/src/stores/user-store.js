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
      if (process.env.DEV) {
        // do nothing in dev mode
      } else {
        apiUser
          .get("/id")
          .then(response => {
            if (response.status === 200) {
              this.user = response.data;
            } else {
              this.user = null;
            }
          })
          .catch(error => {
            console.log(error.response);
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not fetch user information",
              icon: "report_problem",
            });
          });
      }
    },

    logIn(userId, password, closeDialog) {
      if (process.env.DEV) {
        if (userId == "mock") {
          console.log(`DEV MODE: Adding mock user ` + userId);
          this.user = "Mock User";
          closeDialog();
        } else {
          this.$q.notify({
            color: "negative", position: "top",
            message: "Login failed",
            icon: "report_problem",
          });
        }
      } else {
        apiUser
          .post("/login/" + userId, password)
          .then((response) => {
            if (response.status === 200) {
              this.user = response.data;
            } else {
              this.user = null;
            }
          })
          .catch(error => { console.log(error.response); })
          .finally(() => {
            if (this.user == null) {
              this.$q.notify({
                color: "negative", position: "top",
                message: "Login failed",
                icon: "report_problem",
              });
            } else {
              closeDialog();
            }
          });
        };
    },

    logOut() {
      if (process.env.DEV) {
        console.log(`DEV MODE: Removing mock user data`);
        this.user = undefined;
      } else {
        apiUser
          .post("/logout")
          .then(response => {
            this.user = undefined;
          })
          .catch(error => {
            console.log(error.toJSON());
          });
      }
    },
  },
});