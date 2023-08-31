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
          "mock1.mydomain.com": {
            "moduleName": "mockmodule1.my.org",
            "domain": "mock1.mydomain.com",
            "hostName": "xtc-platform.xqiz.it",
            "bindAddr": "xtc-platform.xqiz.it",
            "httpPort": 8102,
            "httpsPort": 8103,
            "active": true,
          },
          "mock2.mydomain.com": {
            "moduleName": "mockmodule2.my.org",
            "domain": "mock2.mydomain.com",
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


    registerWebApp(domain, moduleName, update) {
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
          .post(`/register/${domain}/${moduleName}`)
          .then((response) => {
            if (update) this.updateWebApps()
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

    unregisterWebApp(domain) {
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
          .delete(`/unregister/${domain}`)
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

    startWebApp(domain) {
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
          .post(`/start/${domain}`)
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

    stopWebApp(domain) {
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
          .post(`/stop/${domain}`)
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