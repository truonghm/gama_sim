/**
* Name: sheperd
* Based on the internal skeleton template. 
* Author: truonghm
* Tags: 
*/

model sheperd

global {
	
	float step <- 1 #week;
	string scenario <- "no_regulation";
	bool is_batch <- false;
	
	bool has_no_regulation <- false;
//	float respectful_proba <- 0.0;
	int width <- 50;
	int height <- 50;
	int number_of_goats_per_herd <- 10;
	float goat_eating_cap <- 1.0;
	int eating_season_month_end <- 10;
	int n_months_to_full_growth <- 50;
	float min_spread_seed_proba <- 0.0005;
	int fringe_size <- 8;
	int min_fringe_size <- 4;
	float tree_init_cover <- 0.3;
	int goat_move_range <- 5;
	float threshold_to_eat <- 0.0;

	float global_min_size update: sheperd mean_of (each.min_size);
	float avg_grove_size update: pasture_cell mean_of (each.current_size);
	float tree_cov update: ((pasture_cell count (each.tree = 1)) / (width * height));
	
	list<pasture_cell> empty_cells;
	list<rgb> goat_colors <- [rgb(100,50,255), rgb(255,105,180), rgb(255,255, 0), rgb(0,255,255), rgb(255,255,255), rgb(0,100,250), rgb(255,130,0), rgb(165,42,42)];
	
	int n_respectful_sheperd <- 0;
	int n_disrespectful_sheperd <- length(goat_colors) - n_respectful_sheperd;

	init {
		empty_cells <- list(pasture_cell);
		
		int n <- 0;
		loop c over: goat_colors {
		    
		    create goat number: 10 with: [color:: c] returns: goats_per_sheperd;
		    if n <= n_respectful_sheperd {
		    	create sheperd with: [herd_color:: c, goats:: goats_per_sheperd, is_respectful:: true];
		    } else {
		    	create sheperd with: [herd_color:: c, goats:: goats_per_sheperd, is_respectful:: false];
		    }
		    n <- n + 1;
		}
	    n_respectful_sheperd <- sheperd count each.is_respectful;
	    n_disrespectful_sheperd <- length(goat_colors) - n_respectful_sheperd;
	}
	
	reflex save_result when: every (1 #month)  and !is_batch {
			save [
				int(self),
				tree_cov, 
				n_respectful_sheperd, 
				n_disrespectful_sheperd, 
				global_min_size,
				avg_grove_size,
				current_date.month,
				current_date.year
			] 
		   		to: "results_" + scenario + ".csv" format:"csv" rewrite: (cycle = 0) ? true : false header: true;
	}

	reflex stop_simulation when: (time > 420#month) or (tree_cov = 0.0) or (tree_cov > 0.99) and !is_batch {
		do pause;
	} 
}

grid pasture_cell height: height width: width neighbors: fringe_size {

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

	reflex plant_seed when: tree = 0 {
		int nb_tree_count <- fringe count (each.tree = 1.0);
		if nb_tree_count >= min_fringe_size {
			has_tree <- flip(min_spread_seed_proba * nb_tree_count);
		}
	}
}

species sheperd {
	int min_size <- 0;
	rgb herd_color;
	list<goat> goats;
	bool is_respectful;
	list<int> unique_months <- [];

	init {
		loop g over: goats {
			g.is_respectful <- is_respectful;
		}
	}
	
	reflex check_month when: every (1#month) {
		loop g over: goats {
			if g.unique_months contains current_date.month {
				add current_date.month to: unique_months;
				break;
			}
		}
	}
	reflex compute_min_size when: current_date.month = 1 {
		min_size <- eating_season_month_end - length(unique_months);
		unique_months <- [];
		loop g over: goats {
			g.herd_min_size <- min_size;
		}
	}
}

species goat {
    rgb color;
    bool is_respectful;
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
    }
    
    reflex check_month when: every (1#month) {
		if not (unique_months contains current_date.month) {
			add current_date.month to: unique_months;
//			n_months_graze_tree <- n_months_graze_tree + 1;
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
	
	parameter "Scenario alias: " var: scenario category: "Initialization";
	parameter "Eating season - Month end: " var: eating_season_month_end category: "Initialization";
	parameter "Initial grove coverage: " var: tree_init_cover category: "Initialization" min: 0.0 max: 1.0 step: 0.1 slider: true;
	
	parameter "Disable regulation completely: " var: has_no_regulation category: "Sheperd and goat";
	parameter "Number of goat per herd: " var: number_of_goats_per_herd category: "Sheperd and goat";
	parameter "Grazing Capacity of goat: " var: goat_eating_cap category: "Sheperd and goat" min: 0.0 max: 1.0 step: 0.1 slider: true;
	parameter "Goat perceive/move range: " var: goat_move_range category: "Sheperd and goat";
	
	parameter "Number of months for tree groves to fully grow" var: n_months_to_full_growth category: "Tree groves" step: 5 slider: true;
	parameter "Minimum probability to spread seed: " var: min_spread_seed_proba category: "Tree groves" min: 0.0 max: 1.0;
	parameter "Fringe/Neighbor size: " var: fringe_size category: "Tree groves" ;
	parameter "Minimum fringe size for seed to spread: " var: min_fringe_size category: "Tree groves" ;

	output {
		monitor "Current month" value: current_date.month;
		display grid {
			grid pasture_cell;
			species goat;
			
		}

		display charts refresh: every (12 #month) {
			chart "Average grove size vs Institutional minimum size" type:series background:rgb(255,255,255) {
				data "avg min size" legend: "Ins. min size" value: global_min_size color:#green marker: false style: line;
				data "avg grove size" legend: "Avg grove size" value: avg_grove_size color: #red marker: false style: line;
			}

			chart "Grove coverage (fully grown only) at the beginning of grazing season" type:series  background:rgb(255,255,255) {
				data "grove cov fully grow" value: tree_cov color:#red marker: false style: line;
			}
		}
		
		display charts refresh: every (1 #month) {
			chart "Grove coverage (fully grown only) through time" x_tick_unit: 12 type:series  background:rgb(255,255,255) {
				data "grove cov fully grow" value: tree_cov color:#red marker: false style: line;
			}
		}
	}
}

experiment optimize type: batch repeat: 2 keep_seed: true until: time > 5#year {
	parameter "Grazing Capacity of goat: " var: goat_eating_cap category: "Sheperd and goat" min: 0.1 max: 1.0 step: 0.1;
	parameter "Minimum probability to spread seed: " var: min_spread_seed_proba category: "Tree groves" min: 0.0005 max: 0.125 step: 0.0005;
	parameter "Number of respectful sheperds: " var: n_respectful_sheperd category: "Sheperd and goat" min: 0 max: length(goat_colors) step: 1 slider: true;
	parameter "Batch mode:" var: is_batch <- true;
	
    method tabu 
        iter_max: 10 tabu_list_size: 3 
        minimize: abs(tree_cov - 0.6);
	
	reflex save_results_explo {
		ask simulations {
			save [
				int(self),
				tree_cov,
				global_min_size,
				avg_grove_size,
				n_respectful_sheperd, 
				n_disrespectful_sheperd, 
				goat_eating_cap,
				min_spread_seed_proba,
				current_date.month,
				current_date.year
			] 
		   		to: "optim.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
}
