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
    },

    updateWebApps() {
      if (process.env.DEV) {
        /*
         * mock data for local testing
         */
        console.log(`DEV MODE: Adding mock webapp data`);
        this.webAppsJSON = {
          $type: "ListMap<String, common.model2.WebAppInfo>",
          welcome: {
            moduleName: "welcome.examples.org",
            domain: "welcome",
            hostName: "xtc-platform.xqiz.it",
            bindAddr: "xtc-platform.xqiz.it",
            httpPort: 8100,
            httpsPort: 8101,
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
          .catch(() => {
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
            if (update) this.updateWebApp()
          })
          .catch(() => {
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


  },
});
