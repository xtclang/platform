import { defineStore } from 'pinia';
import { apiWebApp } from "boot/axios";
import { useQuasar } from "quasar";

export const useWebAppStore = defineStore('webApp', {
  state: () => ({
    webAppsJSON: {},
    $q: useQuasar()
  }),

  getters: {
    webApps: (state) => state.webAppsJSON,
  },

  actions: {

    enhance() {
      delete this.webApps['$type']

      for (const [name, webApp] of Object.entries(this.webApps)) {
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
          $type: "ListMap<String, common.model.WebAppInfo>",
          "bank1": {
            "deployment": "bank1",
            "moduleName": "bankStressTest.examples.org",
            "hostName": "xtc-platform.xqiz.it",
            "bindAddr": "xtc-platform.xqiz.it",
            "httpPort": 8100,
            "httpsPort": 8101,
            "active": true,
          },
          "bank2": {
            "deployment": "bank2",
            "moduleName": "bankStressTest.examples.org",
            "hostName": "xtc-platform.xqiz.it",
            "bindAddr": "xtc-platform.xqiz.it",
            "httpPort": 8102,
            "httpsPort": 8103,
            "active": false,
          },
        };
        this.enhance();
      } else {
        /*
         * fetch actual data
         */
        this.$q.loading.show();
        apiWebApp
          .get("/all")
          .then((response) => {
            this.webAppsJSON = response.data;
            this.enhance();
          })
          .catch((error) => {
            console.log(error.toJSON());
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not fetch webapps",
              icon: "report_problem",
            });
          })
          .finally(() => {
            this.$q.loading.hide();
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
            console.log(error.toJSON());
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not register the webapp",
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
            console.log(error.toJSON());
            this.$q.loading.hide();
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not remove the web application",
              icon: "report_problem",
            });
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
            console.log(error.toJSON());
            this.$q.loading.hide();
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not start the web application",
              icon: "report_problem",
            });
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
            console.log(error.toJSON());
            this.$q.loading.hide();
            this.$q.notify({
              color: "negative",
              position: "top",
              message: "Could not stop the web application",
              icon: "report_problem",
            });
          });
      }
    },

  },

});