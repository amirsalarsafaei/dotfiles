{
  services.hyprsunset = {
    enable = true;
    settings = {
      max-gamma = 150;
      profile = [
        {
          time = "7:00";
          identity = true;
        }
        {
          time = "19:00";
          temperature = 4000;
          gamma = 0.9;
        }
      ];
    };
  };
}
