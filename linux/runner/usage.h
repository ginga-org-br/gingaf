#ifndef RUNNER_USAGE_H_
#define RUNNER_USAGE_H_

constexpr const char* kUsageMessage =
    "Usage: gingaf [options] [APP_FILE] [CONFIG_FILE]\n\n"
    "Options:\n"
    "  -h, --help           Show this help message\n"
    "  -c, --config <path>  Path to configuration file\n"
    "  -a, --app <path>     Path to application file\n\n"
    "Environment Variables alternatives (mobile, web):\n"
    "  APP         Path to the application file\n"
    "  CONFIG      Path to the configuration file\n";

#endif
