import { defineStore } from "pinia";
import { apiWebApp } from "boot/axios";
import { useQuasar } from "quasar";

export const useWebAppStore = defineStore("webApp", {
  state: () => ({
    webAppsJSON: {},
    $q: useQuasar()
  }),

  getters: {
    webApps: (state) => state.webAppsJSON,
  },

  actions: {

    enhance() {
      delete this.webApps["$type"] // remove the metadata

      for (const webApp of Object.values(this.webApps)) {
        webApp.displayInfo = webApp.active ? {
          displayText: "Active",
          displayColor: "positive",
          icon: "cloud_done",
        } : {
          displayText: "Inactive",
          displayColor: "negative",
          icon: "cloud_off",
        };
      }
    },

    updateWebApps() {
      if (process.env.DEV) {
        /*
         * mock data for local testing
         */
        console.log(`DEV MODE: Adding mock webapp data`);
        this.webAppsJSON = {
          "bank1": {
            "deployment": "bank1",
            "moduleName": "bankStressTest.examples.org",
            "hostName": "bank1.localhost.xqiz.it",
            "active": Math.random() > 0.5,
          },
          "bank2": {
            "deployment": "bank2",
            "moduleName": "bankStressTest.examples.org",
            "hostName": "bank2.localhost.xqiz.it",
            "active": Math.random() > 0.5,
          },
        };
        this.enhance();
      } else {
        /*
         * fetch actual data
         */
        apiWebApp
          .get("/status")
          .then((response) => {
            this.webAppsJSON = response.data;
            this.enhance();
          })
          .catch((error) => {
            var response = error.response;
            if (response != undefined) {
              console.log(response.data);
              this.$q.notify({
                color: "negative",
                position: "top",
                message: "Could not fetch webapps",
                icon: "report_problem",
              });
            }
          });
      }
    },

    registerWebApp(deployment, moduleName, update) {
      if (process.env.DEV) {
        this.$q.notify({
          color: "info",
          position: "top",
          message: "Operation not available in dev mode",
          icon: "info",
        });
      } else {
        this.$q.loading.show();
        apiWebApp
          .post(`/register/${deployment}/${moduleName}`)
          .then((response) => {
            if (update) {
              this.updateWebApps()
            }
          })
          .catch((error) => {
            console.log(error.response.data);
            this.$q.notify({
              color: "negative",
              position: "top",
              message: error.response.data,
              icon: "report_problem",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
          });
      }
    },

    unregisterWebApp(deployment) {
      if (process.env.DEV) {
        this.$q.notify({
          color: "info",
          position: "top",
          message: "Operation not available in dev mode",
          icon: "info",
        });
      } else {
        this.$q.loading.show();
        apiWebApp
          .delete(`/unregister/${deployment}`)
          .then(() => {
            this.updateWebApps()
          })
          .catch((error) => {
            console.log(error.response.data);
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not remove the web application",
              icon: "report_problem",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
          });
      }
    },

    startWebApp(deployment) {
      if (process.env.DEV) {
        this.$q.notify({
          color: "info",
          position: "top",
          message: "Operation not available in dev mode",
          icon: "info",
        });
      } else {
        this.$q.loading.show();
        apiWebApp
          .post(`/start/${deployment}`)
          .then(() => {
            this.updateWebApps()
          })
          .catch((error) => {
            console.log(error.response.data);
            this.$q.notify({
              color: "negative",
              position: "top",
              message: error.response.data,
              icon: "report_problem",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
          });
      }
    },

    stopWebApp(deployment) {
      if (process.env.DEV) {
        this.$q.notify({
          color: "info",
          position: "top",
          message: "Operation not available in dev mode",
          icon: "info",
        });
      } else {
        this.$q.loading.show();
        apiWebApp
          .post(`/stop/${deployment}`)
          .then(() => {
            this.updateWebApps()
          })
          .catch((error) => {
            console.log(error.response.data);
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not stop the web application",
              icon: "report_problem",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
          });
      }
    },
  },
});