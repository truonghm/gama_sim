/**
* Name: sheperd
* Based on the internal skeleton template. 
* Author: truonghm
* Tags: 
*/

model sheperd

global {
	
	float step <- 1 #week;
	
	bool has_no_regulation <- true;
	float respectful_proba <- 0.0;
	int width <- 50;
	int height <- 50;
	float grove_pct <- 0.3;
	int number_of_goats_per_herd <- 4;
	float goat_eating_cap <- 0.6;
	int eating_season_month_end <- 10;
	int n_months_to_full_growth <- 10;
	float min_spread_seed_proba <- 0.0025;
	int fringe_size <- 8;
	int min_fringe_size <- 2;
	float tree_init_cover <- 0.3;
	int goat_move_range <- 4;
	float threshold_to_eat <- 0.0;
	float global_min_size;
	list<pasture_cell> empty_cells;
	list<rgb> goat_colors <- [rgb(100,50,255), rgb(255,105,180), rgb(255,255, 0), rgb(0,255,255), rgb(255,255,255), rgb(0,100,250), rgb(255,130,0), rgb(165,42,42)];
	init {
		empty_cells <- list(pasture_cell);
		loop c over: goat_colors {
		    
		    create goat number: 10 with: [color:: c] returns: goats_per_sheperd;
		    create sheperd with: [herd_color:: c, goats:: goats_per_sheperd];
		}
	}
	
	reflex compute_min_size {
		global_min_size <- sheperd mean_of (each.min_size);
	}
	
	reflex stop_simulation when: ((pasture_cell count (each.tree = 1)) = 0 or (pasture_cell count (each.tree = 1)) = 250) {
		do pause;
	} 
}

grid pasture_cell height: 50 width: 50 neighbors: 8 {

	float max_tree <- 1.0;
	float growth_rate <- max_tree / n_months_to_full_growth;
//	float tree max: max_tree update: tree + growth_rate;
	float tree max: max_tree;
	float current_size;
	rgb color <- rgb(int(144 * (1 - tree)), int(238 - 138 * tree), int(144 * (1 - tree))) update: rgb(int(144 * (1 - tree)), int(238 - 138 * tree), int(144 * (1 - tree)));
	bool has_tree <- flip(tree_init_cover);
	list<pasture_cell> neighbors_to_move  <- (self neighbors_at goat_move_range);
	list<pasture_cell> fringe <- (self neighbors_at fringe_size);

	init {
		if has_tree {
			tree <- 1.0;
			color <- rgb(0, 100, 0); // full-grown tree to eat
		} else {
			tree <- 0.0;
			color <- rgb(144, 238, 144); // only grass available to eat
		}
	}
	
	reflex grow_tree when: every (1 #month) {
			tree <- tree + growth_rate;
			current_size <- tree / growth_rate;
	}

	reflex plant_tree when: tree = 0 {
		int nb_tree_count <- fringe count (each.tree = 1);
		if nb_tree_count >= min_fringe_size {
			has_tree <- flip(min_spread_seed_proba * nb_tree_count);
		}
	}
}

species sheperd {
	int min_size <- 0;
	rgb herd_color;
	list<goat> goats;

	reflex compute_min_size when: current_date.month = 1 {
		min_size <- eating_season_month_end - goats max_of (each.n_months_graze_tree);
		
		loop g over: goats {
			g.herd_min_size <- min_size;
		}
	}
}

species goat {
    rgb color;
    bool is_respectful <- flip(respectful_proba);
    int herd_min_size <- 0;
//    bool has_grazed_tree <- false;
	int n_months_graze_tree <- 0;
	list<int> unique_months <- [];
	pasture_cell my_cell <- one_of (pasture_cell) ;
	float eating_cap <- goat_eating_cap;

    init {
		location <- my_cell.location;
    }

	reflex reset when: current_date.month = 1 {
		unique_months <- [];
		n_months_graze_tree <- 0;
	}

    reflex move when: (my_cell.tree <= threshold_to_eat) and current_date.month <= eating_season_month_end {
		my_cell <- one_of (my_cell.neighbors_to_move) ;
		location <- my_cell.location ;
    }
    
    action eat_tree {
		my_cell.tree <- my_cell.tree - min([eating_cap, my_cell.tree]);
		if my_cell.tree = 0.0 {
			my_cell.has_tree <- false;
		}
		
		if not (unique_months contains current_date.month) {
			add current_date.month to: unique_months;
			n_months_graze_tree <- n_months_graze_tree + 1;
		}
    }

	reflex eat_tree when: my_cell.tree > threshold_to_eat and current_date.month <= eating_season_month_end { 
		if has_no_regulation {
			do eat_tree;
		} else {
			if not is_respectful {
				if my_cell.current_size >= herd_min_size {
					do eat_tree;
				}
			} else {
				if my_cell.current_size >= global_min_size {
					do eat_tree;
				}
			}
		}
		
	}

    aspect default {
        draw circle(0.8) color: color;
    }
}

experiment sheperd_exp type: gui {
	output {
//		monitor "Current month" value: current_date.month;
		display grid {
			grid pasture_cell;
			species goat;
			
		}

		display charts refresh: every (12 #month) {
			chart "charts" type:series background:rgb(255,255,255){
				data "avg min size" value: global_min_size color:#green marker: false style: line;
				data "avg grove size" value: pasture_cell mean_of (each.current_size) color: #red marker: false style: line;
			}
		}
	}
}
