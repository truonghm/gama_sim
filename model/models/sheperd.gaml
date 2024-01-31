/**
* Name: sheperd
* Based on the internal skeleton template. 
* Author: truonghm
* Tags: 
*/

model sheperd

global {
	int width <- 50;
	int height <- 50;
	float grove_pct <- 0.3;
	int number_of_goats <- 100;
	int number_of_goats_per_herd <- 10;
	float goat_eating_cap <- 1.0;
	float min_growth_rate <- 0.0001;
	float max_growth_rate <- min_growth_rate * 8;
	int eating_season_month_end <- 10;
	int fringe_size <- 8;
	int min_fringe_size <- 6;
	float tree_init_cover <- 0.3;
	int goat_move_range <- 4;
	float threshold_to_eat <- 0.5;
	
	float step <- 1 #week;
	
	list<pasture_cell> empty_cells;
	list<rgb> goat_colors <- [rgb(255,0,0), rgb(255,105,180), rgb(128,0,128), rgb(0,255,255), rgb(0,0,255), rgb(0,128,0), rgb(255,165,0), rgb(165,42,42)];
	init {
		empty_cells <- list(pasture_cell);
//		create grove number: width * height * grove_pct;
		loop c over: goat_colors {
		    
		    create goat number: 10 with: [color:: c] returns: goats_per_sheperd;
		    create sheperd with: [herd_color:: c, goats:: goats_per_sheperd];
		}
	}
}

grid pasture_cell height: 50 width: 50 neighbors: 4 {
//	rgb color <- #darkseagreen;
	float max_tree <- 1.0;
	float growth_rate <- min_growth_rate max: max_growth_rate;
	float tree max: max_tree;
	bool has_tree <- flip(tree_init_cover);
	init {
		if has_tree {
			tree <- 1.0;
			color <- rgb(0, 100, 0);
		} else {
			tree <- 0.0;
			color <- rgb(144, 238, 144);
		}
	}
	list<pasture_cell> neighbors_to_move  <- (self neighbors_at goat_move_range);
	list<pasture_cell> fringe <- (self neighbors_at fringe_size);
	reflex grow_tree when: tree < 1.0 {
		int nb_tree_count <- fringe count (each.tree > 0);
//		if color != rgb(144, 238, 144) and nb_tree_count >= min_fringe_size{
		if nb_tree_count >= min_fringe_size {
			color <- rgb(int(144 * (1 - tree)), int(238 - 138 * tree), int(144 * (1 - tree)));
			tree <- tree + growth_rate * nb_tree_count;
		}

	}
	
	reflex update_tree_status {
		if tree = 0.0 {
			has_tree <- false;
			growth_rate <- min_growth_rate;
		} else {
			has_tree <- true;
		}
	}
	
}

species sheperd {
	int min_size <- 0;
	rgb herd_color;
	list<goat> goats;
	
	reflex compute_min_size when: current_date.month = 10 {
		min_size <- 0;
		list<int> unique_months <- [];
		int n_goats_grazing_tree <- goats count each.is_grazing_tree;
		if !(unique_months contains current_date.month) and n_goats_grazing_tree > 0 and current_date.month <= eating_season_month_end {
			add current_date.month to: unique_months;
			min_size <- min_size + 1;
		}
		
		loop g over: goats {
			g.herd_min_size <- min_size;
		}
	}
}

species goat {
    rgb color <- #beige;
    bool is_respectful;
    int herd_min_size <- 0;
    bool is_grazing_tree <- false;
	pasture_cell my_cell <- one_of (pasture_cell) ;
	float eating_cap <- goat_eating_cap;
    init {
	location <- my_cell.location;
    }
		
    reflex basic_move when: my_cell.tree < threshold_to_eat and current_date.month <= eating_season_month_end {
	my_cell <- one_of (my_cell.neighbors_to_move) ;
	location <- my_cell.location ;
    }
    
	reflex eat when: my_cell.tree >= threshold_to_eat and current_date.month <= eating_season_month_end { 
		my_cell.tree <- my_cell.tree - min([eating_cap, my_cell.tree]);
		is_grazing_tree <- true;
	}


    aspect default {
        draw circle(0.8) color: color;
    }
}

experiment sheperd_exp type: gui {
	output {
		monitor "Current month" value: current_date.month;
		display grid {
			grid pasture_cell;
//			species grove;
			species goat;
			
		}
	}
}
