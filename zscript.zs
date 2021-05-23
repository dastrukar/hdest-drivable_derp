version 4.5


// Hacked DERP Bot
class HDERPBot : HDUPK {
    HDPlayerPawn driver;
    float accel;
    float max_speed;
    float turn_speed;
    bool use_mouse;

    default {
        +Actor.ISMONSTER
        +Actor.NOBLOCKMONST
        +Actor.SHOOTABLE
        +Actor.FRIENDLY
        +Actor.NOFEAR
        +Actor.DONTGIB
        +Actor.NOBLOOD
        +Actor.GHOST
        -Actor.NOGRAVITY

        Health 100;
        Mass 20;
        Speed 0;
        DamageFactor "Thermal", 0.7;
        DamageFactor "Normal", 0.8;
        Radius 4;
        Height 8;
        DeathHeight 8;
        MaxDropOffHeight 4;
        MaxStepHeight 4;
        BloodColor "22 22 22";
        Scale 0.6;
        HDUPK.PickupSound "derp/crawl";
        HDUPK.PickupMessage ""; // Let the pickup do this
        Tag "H.D.E.R.P. robot";
    }

    override void BeginPlay() {
        max_speed = 20;
        turn_speed = 2;
    }

    override void Tick() {
        Super.Tick();
        if (driver) {
            // Turn
            if (driver.player.cmd.buttons & BT_MOVELEFT) {
                angle += turn_speed;
            } else if (driver.player.cmd.buttons & BT_MOVERIGHT) {
                angle -= turn_speed;
            }

            // 360 degree is the limit :]
            if (angle > 360) {
                angle = 1;
            } else if (angle < 0) {
                angle = 359;
            }

            // Drive
            if (driver.player.cmd.buttons & BT_FORWARD) {
                // Accelerate
                speed += 0.1;
            } else if (driver.player.cmd.buttons & BT_BACK) {
                // Decelerate
                if (vel.x > 0 || vel.y > 0) {
                    speed -= 0.2;
                } else {
                    speed -= 0.1;
                }
            } else if (speed != 0) {
                // Decelerate
                bool is_negative = (speed < 0);
                let new_speed = (is_negative)? speed + 0.1 : speed - 0.1;
                speed = (is_negative)? max(new_speed, speed) : min(new_speed, speed);
            }

            // Make sure you aren't flying at the speed of light
            speed = clamp(speed, -max_speed, max_speed);

            Vector2 nv2 = (cos(angle), sin(angle)) * speed;
            if (floorz >= pos.z) {
                if (TryMove(pos.xy+nv2, true)) {
                    driver.SetOrigin(pos, true);
                    //driver.TryMove(pos.xy+nv2, true);
                } else {
                    speed = 0;
                }
            }

            Console.PrintF(string.Format(
                "=HDERP= Speed:%f Angle:%d",
                speed, angle
            ));
        }
    }

    override void A_HDUPKGive() {
        if (!picktarget.player) return;

        if (!driver) {
            driver = HDPlayerPawn(picktarget);
            driver.SetOrigin(pos, true);
            return;
            Super.A_HDUPKGive();
        }
    }

    States {
        Give:
            DERP A 0 {
                HDPlayerPawn hdp = HDPlayerPawn(target);
                if (hdp && !driver) {
                    driver = hdp;
                    driver.SetOrigin(pos, true);
                    return;
                }
            }
            goto Spawn;
        Spawn:
            DERP A 1;
            loop;

        Death:
            DERP A -1;
            stop;
    }
}

class DDERPUiHandler : EventHandler {
    override void WorldLoaded(WorldEvent e) {
        // Enter UI mode
        self.IsUiProcessor = true;
    }
}
